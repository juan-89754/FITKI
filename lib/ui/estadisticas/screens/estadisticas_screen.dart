import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/preferences/app_preferences.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/estadisticas/estadisticas_logic.dart';
import '../../../logic/carga_deuda.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../estadisticas_providers.dart';

List<Color> get _paletaPie => [
  AppColors.primary,
  AppColors.coral,
  AppColors.orange,
  AppColors.oliveGreen,
  AppColors.grayOlive,
  ...AppColors.paletaGraficas,
];

const _mesesAbr = [
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];

class EstadisticasScreen extends ConsumerWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datosAsync = ref.watch(estadisticasDatosProvider);
    final umbral = ref.watch(umbralCargaDeudaProvider).valueOrNull ??
        AppPreferences.umbralCargaDeudaDefault;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: datosAsync.when(
        data: (datos) => _contenido(datos, umbral),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar estadísticas: $e',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.coral,
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(EstadisticasDatos datos, double umbral) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardGrafico(
            titulo: 'Resumen',
            icon: Icons.dashboard_rounded,
            child: _ResumenGrid(datos: datos, umbral: umbral),
          ),
          const SizedBox(height: 16),
          _CardGrafico(
            titulo: 'Gastos por categoría · mes actual',
            icon: Icons.pie_chart_rounded,
            child: _PieGastos(gastos: datos.gastosPorCategoria),
          ),
          const SizedBox(height: 16),
          _CardGrafico(
            titulo: 'Evolución del patrimonio · últimos '
                '${EstadisticasLogic.mesesEvolucion} meses',
            icon: Icons.timeline_rounded,
            child: _LineEvolucion(puntos: datos.evolucionPatrimonio),
          ),
          const SizedBox(height: 16),
          _CardGrafico(
            titulo: 'Deudas vs ingresos del mes',
            icon: Icons.compare_arrows_rounded,
            child: _BarrasDeudasVsIngresos(datos: datos),
          ),
        ],
      ),
    );
  }
}

class _CardGrafico extends StatelessWidget {
  final String titulo;
  final IconData icon;
  final Widget child;

  const _CardGrafico({
    required this.titulo,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResumenGrid extends StatelessWidget {
  final EstadisticasDatos datos;
  final double umbral;

  const _ResumenGrid({required this.datos, required this.umbral});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    // Carga mensual de deuda: cuotas de las deudas activas vs. ingresos del
    // mes, comparadas contra el umbral configurado por el usuario (fracción
    // en prefs). El total pendiente se muestra aparte para no mezclar un
    // acumulado con los ingresos de un solo mes.
    final carga = calcularCargaDeuda(
      datos.totalCuotasMensuales,
      datos.ingresosMes,
      umbral: umbral,
    );

    final tarjetas = [
      _DatoResumen(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.primary,
        label: 'Patrimonio total',
        valor: currency(datos.patrimonioTotal),
      ),
      _DatoResumen(
        icon: Icons.trending_up_rounded,
        iconColor: datos.balanceMes >= 0
            ? AppColors.primary
            : AppColors.coral,
        label: 'Balance del mes',
        valor: currency(datos.balanceMes),
      ),
      _DatoResumen(
        icon: Icons.flag_rounded,
        iconColor: AppColors.orange,
        label: 'Progreso de metas',
        valor: datos.progresoMetas == null
            ? '—'
            : '${datos.progresoMetas!.promedio.toStringAsFixed(0)}%',
        detalle: datos.progresoMetas == null
            ? 'Sin metas con objetivo'
            : '${datos.progresoMetas!.conObjetivo} '
                'de ${datos.progresoMetas!.totalMetas} metas',
      ),
      _DatoResumen(
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.primary,
        label: 'Deuda total pendiente',
        valor: currency(datos.totalDeudasPendientes),
      ),
      _DatoResumen(
        icon: Icons.warning_amber_rounded,
        iconColor: carga.excedeUmbral ? AppColors.coral : AppColors.primary,
        label: 'Carga mensual de deuda',
        valor: '${carga.porcentaje.toStringAsFixed(0)}%',
        detalle: '${currency(carga.cuotaMensualTotal)} en cuotas',
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tarjetas[0]),
            const SizedBox(width: 12),
            Expanded(child: tarjetas[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: tarjetas[2]),
            const SizedBox(width: 12),
            Expanded(child: tarjetas[3]),
          ],
        ),
      ],
    );
  }
}

class _DatoResumen extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String valor;
  final String? detalle;

  const _DatoResumen({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valor,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!,
          ),
          if (detalle != null) ...[
            const SizedBox(height: 2),
            Text(
              detalle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontSize: 10,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PieGastos extends StatelessWidget {
  final List<GastoCategoria> gastos;

  const _PieGastos({required this.gastos});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    if (gastos.isEmpty) {
      return const _SinDatos(mensaje: 'Sin gastos registrados este mes');
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: [
                for (var i = 0; i < gastos.length; i++)
                  PieChartSectionData(
                    value: gastos[i].total,
                    color: _paletaPie[i % _paletaPie.length],
                    radius: 48,
                    title:
                        '${gastos[i].porcentaje.toStringAsFixed(0)}%',
                    titleStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                    titlePositionPercentageOffset: 0.6,
                  ),
              ],
              centerSpaceRadius: 34,
              sectionsSpace: 2,
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < gastos.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _paletaPie[i % _paletaPie.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${labelCategoria(gastos[i].categoria)} · '
                    '${currency(gastos[i].total)}',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _LineEvolucion extends StatelessWidget {
  final List<PuntoEvolucion> puntos;

  const _LineEvolucion({required this.puntos});

  @override
  Widget build(BuildContext context) {
    if (puntos.length < 2) {
      return const _SinDatos(mensaje: 'Datos insuficientes para la evolución');
    }

    final valores = puntos.map((p) => p.valor);
    var min = valores.reduce((a, b) => a < b ? a : b);
    var max = valores.reduce((a, b) => a > b ? a : b);
    if (min == max) {
      min -= 1;
      max += 1;
    } else {
      final rango = max - min;
      min -= rango * 0.15;
      max += rango * 0.15;
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (puntos.length - 1).toDouble(),
          minY: min,
          maxY: max,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.borderSubtle,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= puntos.length) {
                    return const SizedBox.shrink();
                  }
                  final index = value
                      .round();
return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _mesesAbr[puntos[index].fecha.month - 1],
                      style: Theme.of(context).textTheme.labelSmall!,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: (max - min) / 3,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _abreviarMonto(value),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            fontSize: 10,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < puntos.length; i++)
                  FlSpot(i.toDouble(), puntos[i].valor),
              ],
              color: AppColors.primary,
              barWidth: 3,
              isCurved: true,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  String _abreviarMonto(double valor) {
    if (valor.abs() >= 1000000) {
      return '\$${(valor / 1000000).toStringAsFixed(1)}M';
    }
    if (valor.abs() >= 1000) {
      return '\$${(valor / 1000).toStringAsFixed(0)}k';
    }
    return '\$${valor.toStringAsFixed(0)}';
  }
}

class _BarrasDeudasVsIngresos extends StatelessWidget {
  final EstadisticasDatos datos;

  const _BarrasDeudasVsIngresos({required this.datos});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    final maxValor = datos.ingresosMes > datos.totalDeudasPendientes
        ? datos.ingresosMes
        : datos.totalDeudasPendientes;
    if (maxValor <= 0) {
      return const _SinDatos(
        mensaje: 'Registra ingresos o deudas para comparar',
      );
    }

    return Column(
      children: [
        _BarraComparativa(
          label: 'Ingresos del mes',
          valor: datos.ingresosMes,
          currency: currency,
          color: AppColors.primary,
          fraccion: datos.ingresosMes / maxValor,
        ),
        const SizedBox(height: 14),
        _BarraComparativa(
          label: 'Deudas pendientes',
          valor: datos.totalDeudasPendientes,
          currency: currency,
          color: AppColors.coral,
          fraccion: datos.totalDeudasPendientes / maxValor,
        ),
        const SizedBox(height: 14),
        Text(
          datos.ingresosMes > 0
              ? 'Las deudas equivalen al '
                  '${((datos.totalDeudasPendientes / datos.ingresosMes) * 100).toStringAsFixed(0)}% '
                  'de tus ingresos del mes.'
              : 'Aún no registras ingresos este mes.',
          style: Theme.of(context).textTheme.bodySmall!,
        ),
      ],
    );
  }
}

class _BarraComparativa extends StatelessWidget {
  final String label;
  final double valor;
  final String Function(double) currency;
  final Color color;
  final double fraccion;

  const _BarraComparativa({
    required this.label,
    required this.valor,
    required this.currency,
    required this.color,
    required this.fraccion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraccion.clamp(0.0, 1.0),
              minHeight: 14,
              color: color,
              backgroundColor: AppColors.surfaceSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            currency(valor),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SinDatos extends StatelessWidget {
  final String mensaje;

  const _SinDatos({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.grayOlive, size: 28),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}