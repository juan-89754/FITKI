import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../data/models/quote_project.dart';
import '../../../data/models/quote.dart';
import '../../../logic/cotizaciones/cotizaciones_logic.dart';
import '../cotizaciones_providers.dart';
import 'cotizacion_detalle_screen.dart';
import 'cotizacion_form_screen.dart';
import 'proyecto_form_screen.dart';

class ProyectoDetalleScreen extends ConsumerWidget {
  final QuoteProject proyecto;

  const ProyectoDetalleScreen({super.key, required this.proyecto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cotizaciones =
        ref.watch(cotizacionesStreamProvider).asData?.value ?? const [];
    final items = ref.watch(itemsStreamProvider).asData?.value ?? const [];

    QuoteProject actual = proyecto;
    final proyectos =
        ref.watch(proyectosStreamProvider).asData?.value ?? const [];
    for (final p in proyectos) {
      if (p.id == proyecto.id) {
        actual = p;
        break;
      }
    }

    final delProyecto = cotizaciones
        .where((c) => c.proyectoId == proyecto.id)
        .toList();
    final comparativa = CotizacionesLogic.compararCotizaciones([
      for (final c in delProyecto)
        (
          c,
          items
              .where((item) => item.cotizacionId == c.id)
              .toList(),
        ),
    ]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de proyecto'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar proyecto',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _Encabezado(
            proyecto: actual,
            onEditar: () => _editarProyecto(context, ref, actual),
          ),
          const SizedBox(height: 16),
          if (comparativa.isEmpty)
            _SinCotizaciones(
              onAgregar: () => _abrirFormularioCotizacion(context, ref),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Comparación de cotizaciones',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _ResumenComparativa(comparativa: comparativa),
            const SizedBox(height: 12),
            ...comparativa.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CotizacionCard(
                      comparacion: entry.value,
                      posicion: entry.key + 1,
                      totalCotizaciones: comparativa.length,
                      onTap: () => _abrirDetalleCotizacion(
                        context,
                        ref,
                        entry.value.cotizacion,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioCotizacion(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva cotización'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  void _abrirFormularioCotizacion(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CotizacionFormScreen(
              proyectoId: proyecto.id!,
            ),
          ),
        )
        .then((guardado) {
      if (guardado == true) ref.invalidate(cotizacionesStreamProvider);
    });
  }

  void _abrirDetalleCotizacion(BuildContext context, WidgetRef ref, Quote c) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CotizacionDetalleScreen(cotizacion: c),
          ),
        )
        .then((cambio) {
      if (cambio == true) {
        ref.invalidate(cotizacionesStreamProvider);
        ref.invalidate(itemsStreamProvider);
      }
    });
  }

  void _editarProyecto(BuildContext context, WidgetRef ref, QuoteProject p) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ProyectoFormScreen(proyecto: p)))
        .then((guardado) {
      if (guardado == true) ref.invalidate(proyectosStreamProvider);
    });
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    QuoteProject proyecto,
  ) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Eliminar proyecto',
      message:
          'Se eliminará el proyecto y sus cotizaciones e items. ¿Continuar?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmado != true) return;

    try {
      await ref.read(proyectoRepositoryProvider).delete(proyecto.id!);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo eliminar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }
    ref.invalidate(proyectosStreamProvider);
    ref.invalidate(cotizacionesStreamProvider);
    ref.invalidate(itemsStreamProvider);
    if (context.mounted) Navigator.pop(context, true);
  }
}

class _Encabezado extends StatelessWidget {
  final QuoteProject proyecto;
  final VoidCallback onEditar;

  const _Encabezado({required this.proyecto, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.ballot_rounded,
                color: AppColors.textOnPrimary, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proyecto.titulo,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  if (proyecto.objetivo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      proyecto.objetivo,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        color:
                            AppColors.textOnPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_rounded,
                  color: AppColors.textOnPrimary),
              tooltip: 'Editar proyecto',
            ),
          ],
        ),
      ),
    );
  }
}





class _ResumenComparativa extends StatelessWidget {
  final List<ComparacionCotizacion> comparativa;

  const _ResumenComparativa({required this.comparativa});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final mejor = comparativa.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mintPale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppColors.orange, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'La más económica es "${mejor.cotizacion.titulo}" con '
              '${currency(mejor.total)}.',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CotizacionCard extends StatelessWidget {
  final ComparacionCotizacion comparacion;
  final int posicion;
  final int totalCotizaciones;
  final VoidCallback onTap;

  const _CotizacionCard({
    required this.comparacion,
    required this.posicion,
    required this.totalCotizaciones,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: comparacion.esMasEconomica
              ? AppColors.orange
              : AppColors.borderSubtle,
          width: comparacion.esMasEconomica ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: comparacion.esMasEconomica
                      ? AppColors.orange.withValues(alpha: 0.15)
                      : AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  comparacion.esMasEconomica
                      ? Icons.emoji_events_rounded
                      : Icons.receipt_long_rounded,
                  color: comparacion.esMasEconomica
                      ? AppColors.orange
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comparacion.cotizacion.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (comparacion.esMasEconomica) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Más económica',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall!
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orange,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Opción #$posicion de $totalCotizaciones',
                      style: Theme.of(context).textTheme.bodySmall!,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.bodySmall!,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency(comparacion.total),
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: comparacion.esMasEconomica
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SinCotizaciones extends StatelessWidget {
  final VoidCallback onAgregar;

  const _SinCotizaciones({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.mintPale,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no hay cotizaciones',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agrega varias cotizaciones para comparar\nprecios y elegir la mejor.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva cotización'),
          ),
        ],
      ),
    );
  }
}