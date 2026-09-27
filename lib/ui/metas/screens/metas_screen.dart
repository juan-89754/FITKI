import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/financial_goal.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/metas/metas_logic.dart';
import '../metas_providers.dart';
import 'meta_detalle_screen.dart';
import 'meta_form_screen.dart';

class MetasScreen extends ConsumerWidget {
  const MetasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(metasStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Metas financieras'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: metasAsync.when(
        data: (metas) {
          if (metas.isEmpty) {
            return _EstadoVacio(
              onAgregar: () => _abrirFormulario(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: metas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final meta = metas[index];
              return _MetaCard(
                calculo: MetasLogic.calcular(meta),
                onTap: () => _abrirDetalle(context, ref, meta),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar metas: $e',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.coral,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva meta'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  void _abrirFormulario(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MetaFormScreen()))
        .then((guardado) {
      if (guardado == true) ref.invalidate(metasStreamProvider);
    });
  }

  void _abrirDetalle(BuildContext context, WidgetRef ref, FinancialGoal meta) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MetaDetalleScreen(meta: meta)))
        .then((cambio) {
      if (cambio == true) ref.invalidate(metasStreamProvider);
    });
  }
}

class _MetaCard extends StatelessWidget {
  final MetaCalculo calculo;
  final VoidCallback onTap;

  const _MetaCard({required this.calculo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = calculo.meta;

    return Card(
      elevation: 0,
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
              _progresoCircular(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.nombre,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelFinalidad(meta.finalidad),
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _lineaInformacion(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progresoCircular(BuildContext context) {
    final meta = calculo.meta;

    if (meta.montoObjetivo == null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.mintPale,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.savings_rounded,
          color: AppColors.primary,
          size: 28,
        ),
      );
    }

    final progreso = (calculo.porcentajeProgreso / 100).clamp(0.0, 1.0);
    final cumplida = calculo.cumpleObjetivo;
    final color = cumplida ? AppColors.primary : AppColors.orange;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: progreso,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: AppColors.surfaceSecondary,
            ),
          ),
          Text(
            '${calculo.porcentajeProgreso.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaInformacion(BuildContext context) {
    final meta = calculo.meta;
    const currency = AppFormat.moneda;

    final partes = <String>[
      '${currency(meta.montoAhorrado)} ahorrados',
      if (meta.montoObjetivo != null)
        'de ${currency(meta.montoObjetivo!)}',
      if (meta.fechaEstimada != null)
        '· ${DateFormat('dd MMM yyyy').format(meta.fechaEstimada!)}',
    ];

    return Text(
      partes.join(' '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall!,
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
                Icons.flag_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes metas aún',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una meta de ahorro y calcula\ncuánto necesitas por semana o mes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear meta'),
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