import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/quote_project.dart';
import '../cotizaciones_providers.dart';
import 'proyecto_detalle_screen.dart';
import 'proyecto_form_screen.dart';

class ProyectosScreen extends ConsumerWidget {
  const ProyectosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectosAsync = ref.watch(proyectosStreamProvider);
    final cotizaciones = ref.watch(cotizacionesStreamProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cotizaciones'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: proyectosAsync.when(
        data: (proyectos) {
          if (proyectos.isEmpty) {
            return _EstadoVacio(
              onAgregar: () => _abrirFormulario(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: proyectos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final proyecto = proyectos[index];
              final cantidad = cotizaciones
                      ?.where((c) => c.proyectoId == proyecto.id)
                      .length ??
                  0;
              return _ProyectoCard(
                proyecto: proyecto,
                cantidadCotizaciones: cantidad,
                onTap: () => _abrirDetalle(context, ref, proyecto),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar proyectos: $e',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.coral,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo proyecto'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  void _abrirFormulario(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProyectoFormScreen()))
        .then((guardado) {
      if (guardado == true) ref.invalidate(proyectosStreamProvider);
    });
  }

  void _abrirDetalle(
    BuildContext context,
    WidgetRef ref,
    QuoteProject proyecto,
  ) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ProyectoDetalleScreen(proyecto: proyecto),
          ),
        )
        .then((cambio) {
      if (cambio == true) ref.invalidate(proyectosStreamProvider);
    });
  }
}

class _ProyectoCard extends StatelessWidget {
  final QuoteProject proyecto;
  final int cantidadCotizaciones;
  final VoidCallback onTap;

  const _ProyectoCard({
    required this.proyecto,
    required this.cantidadCotizaciones,
    required this.onTap,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mintPale,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proyecto.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (proyecto.objetivo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        proyecto.objetivo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$cantidadCotizaciones '
                          '${cantidadCotizaciones == 1 ? 'cotización' : 'cotizaciones'}',
                          style: Theme.of(context).textTheme.bodySmall!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final VoidCallback onAgregar;

  const _EstadoVacio({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.mintPale,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.ballot_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes proyectos aún',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea un proyecto, agrega varias cotizaciones\ny encuentra la opción más económica.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear proyecto'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}