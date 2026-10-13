import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/gastos/gastos_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../presupuesto_providers.dart';
import '../screens/presupuesto_categoria_form_screen.dart';

/// Presupuesto del mes por categoría: un límite por categoría contra lo que de
/// verdad se gastó en ella.
///
/// No hay partidas que declarar ni monto total que repartir: lo gastado sale
/// siempre de los movimientos reales, así que el plan y la realidad nunca se
/// desincronizan. Es la respuesta a "en qué se me está yendo la plata".
class PresupuestoCategoriasView extends ConsumerWidget {
  const PresupuestoCategoriasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenes = ref.watch(resumenesPresupuestoProvider);
    final gastadoPorCategoria =
        ref.watch(gastadoPorCategoriaMesProvider).asData?.value ??
            const <String, double>{};
    final totales = ref.watch(totalesPresupuestoProvider);
    final periodo = ref.watch(periodoVisibleProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(presupuestosCategoriasStreamProvider);
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
                return _Vacio(
                  icono: Icons.donut_small_rounded,
                  titulo: 'Sin presupuesto para ${periodo.etiqueta}',
                  mensaje:
                      'Ponle un límite a tus categorías y la app lo va '
                      'llenando con lo que registres. Empieza por la que más '
                      'gasta.',
                );
              }
              return Column(
                children: [
                  totales.maybeWhen(
                    data: (t) => _EncabezadoTotales(totales: t),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  for (final resumen in lista)
                    _TarjetaCategoria(resumen: resumen),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Sin presupuesto',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Categorías con gasto este mes a las que todavía no les pusiste un '
            'límite.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final conPresupuesto = resumenes.asData?.value
                      .map((r) => r.categoria)
                      .toSet() ??
                  <String>{};
              final sinPresupuesto = gastadoPorCategoria.entries
                  .where((e) => !conPresupuesto.contains(e.key))
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              if (sinPresupuesto.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Todas las categorías con gasto ya tienen presupuesto.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final entrada in sinPresupuesto)
                    _TarjetaSinPresupuesto(
                      categoria: entrada.key,
                      gastado: entrada.value,
                      alCrear: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PresupuestoCategoriaFormScreen(
                            categoriaInicial: entrada.key,
                          ),
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
}

/// Encabezado con el plan del mes: lo presupuestado, lo gastado y lo que queda,
/// con una barra global de uso.
class _EncabezadoTotales extends StatelessWidget {
  const _EncabezadoTotales({required this.totales});

  final TotalesPresupuesto totales;

  @override
  Widget build(BuildContext context) {
    final superado = totales.superado;
    final colorBarra = superado ? AppColors.coral : AppColors.textOnPrimary;
    final progreso = (totales.porcentaje / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Presupuestado este mes',
            style: TextStyle(
              color: AppColors.textOnPrimary.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppFormat.moneda(totales.presupuestado),
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 9,
              backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CifraClara(
                etiqueta: 'Gastado',
                valor: AppFormat.moneda(totales.gastado),
              ),
              _CifraClara(
                etiqueta: superado ? 'Excedido' : 'Te queda',
                valor: AppFormat.moneda(
                  superado ? totales.gastado - totales.presupuestado : totales.disponible,
                ),
              ),
              _CifraClara(
                etiqueta: 'Uso',
                valor: '${totales.porcentaje.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CifraClara extends StatelessWidget {
  const _CifraClara({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            color: AppColors.textOnPrimary.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _TarjetaCategoria extends StatelessWidget {
  const _TarjetaCategoria({required this.resumen});

  final ResumenPresupuesto resumen;

  @override
  Widget build(BuildContext context) {
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
              Icon(
                iconoCategoria(resumen.categoria),
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  labelCategoria(resumen.categoria),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PresupuestoCategoriaFormScreen(
                        presupuesto: resumen.presupuesto,
                      ),
                    ),
                  ),
                  child: const Text('Editar'),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
                etiqueta: 'Límite',
                valor: AppFormat.moneda(resumen.limite),
                color: AppColors.textPrimary,
              ),
              _Cifra(
                etiqueta: superado ? 'Excedido' : 'Te queda',
                valor: AppFormat.moneda(
                  superado ? resumen.excedido : resumen.restante,
                ),
                color: superado ? AppColors.coral : AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaSinPresupuesto extends StatelessWidget {
  const _TarjetaSinPresupuesto({
    required this.categoria,
    required this.gastado,
    required this.alCrear,
  });

  final String categoria;
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
        leading: Icon(iconoCategoria(categoria), color: AppColors.textSecondary),
        title: Text(
          labelCategoria(categoria),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        subtitle: Text(
          'Llevas ${AppFormat.moneda(gastado)} gastados sin límite',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: alCrear,
          child: const Text('Asignar'),
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
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
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
