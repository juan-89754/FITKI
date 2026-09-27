import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/asset.dart';
import '../../../data/models/gasto_fijo.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/gastos/gastos_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../presupuesto_providers.dart';
import '../screens/presupuesto_activo_form_screen.dart';

/// Busca el activo por id sin recurrir a extensiones de collection.
Asset? _buscarActivo(List<Asset> activos, int? id) {
  if (id == null) return null;
  for (final activo in activos) {
    if (activo.id == id) return activo;
  }
  return null;
}

/// Presupuesto del mes: un límite por activo.
///
/// No hay partidas que declarar ni monto total que repartir. Lo gastado sale
/// siempre de los movimientos reales de esa cuenta, y el desglose por categoría
/// es de solo lectura.
class PresupuestoMensualTab extends ConsumerWidget {
  const PresupuestoMensualTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activos = ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
    final resumenes = ref.watch(resumenesPresupuestoProvider);
    final gastadoPorActivo = ref.watch(gastadoPorActivoMesProvider);
    final periodo = ref.watch(periodoVisibleProvider);
    final fijos = ref.watch(gastosFijosStreamProvider).asData?.value ?? const <GastoFijo>[];

    if (activos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Vacio(
            icono: Icons.account_balance_rounded,
            titulo: 'Primero crea un activo',
            mensaje:
                'El presupuesto se arma sobre una cuenta o activo. Ve a '
                'Activos y crea la cuenta desde la que pagas para poder '
                'presupuestarla aquí.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(presupuestosActivosStreamProvider);
        ref.invalidate(movimientosDelMesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          resumenes.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const _Vacio(
              icono: Icons.error_outline_rounded,
              titulo: 'No se pudo calcular',
              mensaje: 'Intenta de nuevo en un momento.',
            ),
            data: (lista) {
              if (lista.isEmpty) {
                final totalFijos = _totalFijosDelMes(fijos, periodo.mes, periodo.anio);
                return Column(
                  children: [
                    _Vacio(
                      icono: Icons.donut_small_rounded,
                      titulo: 'Sin presupuesto para ${periodo.etiqueta}',
                      mensaje: totalFijos > 0
                          ? 'Tus gastos fijos de este mes suman '
                                '${AppFormat.moneda(totalFijos)}. '
                                'Úsalos de base para el límite.'
                          : 'Crea un límite de gasto para una cuenta y la app '
                                'lo va llenando con lo que registres.',
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  for (final resumen in lista)
                    _TarjetaPresupuesto(
                      resumen: resumen,
                      activo: _buscarActivo(
                        activos,
                        resumen.presupuesto.activoId,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Otras cuentas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final conPresupuesto = resumenes.asData?.value
                      .map((r) => r.presupuesto.activoId)
                      .toSet() ??
                  <int>{};
              final sinPresupuesto = activos
                  .where((a) => !conPresupuesto.contains(a.id))
                  .toList();
              if (sinPresupuesto.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Todas tus cuentas tienen presupuesto este mes.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                );
              }
              return Column(
                children: [
                  for (final activo in sinPresupuesto)
                    _TarjetaSinPresupuesto(
                      activo: activo,
                      gastado: gastadoPorActivo.asData?.value[activo.id] ?? 0,
                      alCrear: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PresupuestoActivoFormScreen(activo: activo),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Suma de lo estimado en los gastos fijos vigentes del mes. Sirve para
  /// proponer un límite con datos reales en vez de inventar la cifra.
  static double _totalFijosDelMes(
    List<GastoFijo> fijos,
    int mes,
    int anio,
  ) {
    return fijos
        .where((f) => f.aplicaEn(mes, anio))
        .fold<double>(0, (acc, f) => acc + f.montoEstimado);
  }
}

class _TarjetaPresupuesto extends ConsumerWidget {
  const _TarjetaPresupuesto({required this.resumen, required this.activo});

  final ResumenPresupuesto resumen;
  final Asset? activo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Copia local: Dart solo promueve variables, no campos, así que sin esto
    // el chequeo de null no le quitaría el '?' al abrir el formulario.
    final cuenta = activo;
    final superado = resumen.superado;
    final colorBarra = superado ? AppColors.coral : AppColors.primary;
    final progreso = (resumen.porcentaje / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activo?.nombre ?? 'Activo eliminado',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Límite ${AppFormat.moneda(resumen.limite)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (superado)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackgroundCoral,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Te pasaste ${AppFormat.moneda(resumen.excedido)}',
                    style: const TextStyle(
                      color: Color(0xFF8C2F1C),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (cuenta != null)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PresupuestoActivoFormScreen(
                        activo: cuenta,
                        presupuesto: resumen.presupuesto,
                      ),
                    ),
                  ),
                  child: const Text('Editar'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 9,
              backgroundColor: AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Cifra(
                etiqueta: 'Gastado',
                valor: AppFormat.moneda(resumen.gastado),
                color: superado ? AppColors.coral : AppColors.textPrimary,
              ),
              _Cifra(
                etiqueta: superado ? 'Excedido' : 'Te queda',
                valor: AppFormat.moneda(
                  superado ? resumen.excedido : resumen.restante,
                ),
                color: superado ? AppColors.coral : AppColors.primary,
              ),
              _Cifra(
                etiqueta: 'Uso',
                valor: '${resumen.porcentaje.toStringAsFixed(0)}%',
                color: AppColors.textPrimary,
              ),
            ],
          ),
          if (resumen.porCategoria.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 12),
            Text(
              'En qué se fue',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final renglon in resumen.porCategoria.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      iconoCategoria(renglon.categoria),
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labelCategoria(renglon.categoria),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      AppFormat.moneda(renglon.monto),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (resumen.porCategoria.length > 5)
              Text(
                '+ ${resumen.porCategoria.length - 5} categorías más',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Todavía no has registrado gastos en esta cuenta este mes.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _TarjetaSinPresupuesto extends StatelessWidget {
  const _TarjetaSinPresupuesto({
    required this.activo,
    required this.gastado,
    required this.alCrear,
  });

  final Asset activo;
  final double gastado;
  final VoidCallback alCrear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          activo.nombre,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        subtitle: Text(
          gastado > 0
              ? 'Llevas ${AppFormat.moneda(gastado)} gastados sin presupuesto'
              : 'Sin presupuesto este mes',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: alCrear,
          child: const Text('Crear'),
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor, required this.color});

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.titulo, required this.mensaje});

  final IconData icono;
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 34, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
