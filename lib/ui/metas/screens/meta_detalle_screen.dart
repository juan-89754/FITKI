import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/financial_goal.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/metas/metas_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../metas_providers.dart';
import 'meta_form_screen.dart';

class MetaDetalleScreen extends ConsumerWidget {
  final FinancialGoal meta;

  const MetaDetalleScreen({super.key, required this.meta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metas = ref.watch(metasStreamProvider).asData?.value ?? const [];
    FinancialGoal? actual = meta;
    for (final m in metas) {
      if (m.id == meta.id) {
        actual = m;
        break;
      }
    }
    final calculo = MetasLogic.calcular(actual!);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de meta'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual!),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar meta',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Encabezado(calculo: calculo),
          const SizedBox(height: 16),
          if (calculo.meta.comentarios != null) ...[
            _CardInfo(
              icon: Icons.sticky_note_2_rounded,
              titulo: 'Comentarios',
              child: Text(
                calculo.meta.comentarios!,
                style: Theme.of(context).textTheme.titleSmall!,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _DesgloseCalculo(calculo: calculo),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _registrarAporte(context, ref, actual!),
            icon: const Icon(Icons.add_chart_rounded),
            label: const Text('Registrar aporte manual'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _editar(context, ref, actual!),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar meta'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarAporte(
    BuildContext context,
    WidgetRef ref,
    FinancialGoal meta,
  ) async {
    final monto = await _dialogoAporte(context);
    if (monto == null || monto <= 0) return;
    try {
      await ref.read(metaRepositoryProvider).agregarAporte(meta.id!, monto);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar el aporte')),
        );
      }
      return;
    }
    ref.invalidate(metasStreamProvider);
  }

  Future<double?> _dialogoAporte(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar aporte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [MilesInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Monto a aportar',
            hintText: 'Ej. 200.000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final valor = milesADouble(controller.text);
              Navigator.pop(ctx, valor);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Aportar'),
          ),
        ],
      ),
    );
  }

  void _editar(BuildContext context, WidgetRef ref, FinancialGoal meta) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MetaFormScreen(meta: meta)))
        .then((guardado) {
      if (guardado == true) ref.invalidate(metasStreamProvider);
    });
  }

  void _eliminar(BuildContext context, WidgetRef ref, FinancialGoal meta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text('¿Eliminar "${meta.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(metaRepositoryProvider).delete(meta.id!);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo eliminar, intenta de nuevo'),
                    ),
                  );
                }
                return;
              }
              ref.invalidate(metasStreamProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final MetaCalculo calculo;

  const _Encabezado({required this.calculo});

  @override
  Widget build(BuildContext context) {
    final meta = calculo.meta;
    const currency = AppFormat.moneda;

    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.nombre,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labelFinalidad(meta.finalidad),
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (calculo.porcentajeProgreso / 100).clamp(0.0, 1.0),
                minHeight: 10,
                color: calculo.cumpleObjetivo
                    ? AppColors.orange
                    : AppColors.textOnPrimary,
                backgroundColor:
                    AppColors.textOnPrimary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${calculo.porcentajeProgreso.toStringAsFixed(0)}% ahorrado',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  meta.montoObjetivo == null
                      ? '${currency(meta.montoAhorrado)} ahorrados'
                      : '${currency(meta.montoAhorrado)} '
                          'de ${currency(meta.montoObjetivo!)}',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesgloseCalculo extends StatelessWidget {
  final MetaCalculo calculo;

  const _DesgloseCalculo({required this.calculo});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final meta = calculo.meta;

    if (meta.montoObjetivo == null) {
      return const _CardInfo(
        icon: Icons.info_outline_rounded,
        titulo: 'Ahorro sin meta fija',
        child: null,
      );
    }

    final filas = <_FilaDesglose>[];
    filas.add(_FilaDesglose(
      label: 'Monto objetivo',
      value: '${currency(meta.montoObjetivo!)}',
    ));
    filas.add(_FilaDesglose(
      label: 'Ahorrado a la fecha',
      value: '${currency(meta.montoAhorrado)}',
    ));
    filas.add(_FilaDesglose(
      label: 'Falta por ahorrar',
      value: '${currency(calculo.montoFaltante!)}',
      destacado: true,
    ));

    if (meta.fechaEstimada == null) {
      filas.add(_FilaDesglose(
        label: 'Fecha estimada',
        value: 'Sin fecha definida',
        valorGris: true,
      ));
    } else {
      final fecha = DateFormat('dd MMM yyyy').format(meta.fechaEstimada!);
      filas.add(_FilaDesglose(label: 'Fecha estimada', value: fecha));
      if ((calculo.semanasRestantes ?? 0) > 0) {
        filas.add(_FilaDesglose(
          label: 'Semanas restantes',
          value: '${calculo.semanasRestantes}',
        ));
        filas.add(_FilaDesglose(
          label: 'Ahorro sugerido por semana',
          value: '${currency(calculo.ahorroSemanal!)}',
          destacado: true,
        ));
      }
      if ((calculo.mesesRestantes ?? 0) > 0) {
        filas.add(_FilaDesglose(
          label: 'Meses restantes',
          value: '${calculo.mesesRestantes}',
        ));
        filas.add(_FilaDesglose(
          label: 'Ahorro sugerido por mes',
          value: '${currency(calculo.ahorroMensual!)}',
          destacado: true,
        ));
      }
      if ((calculo.semanasRestantes ?? 0) == 0 &&
          (calculo.mesesRestantes ?? 0) == 0) {
        filas.add(_FilaDesglose(
          label: 'Tiempo restante',
          value: 'Fecha vencida',
          valorGris: true,
        ));
      }
    }

    if (calculo.cumpleObjetivo) {
      filas.add(_FilaDesglose(
        label: 'Estado',
        value: 'Meta cumplida 🎉',
        destacado: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Desglose del cálculo',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: filas
                  .map((fila) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: fila,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaDesglose extends StatelessWidget {
  final String label;
  final String value;
  final bool destacado;
  final bool valorGris;

  const _FilaDesglose({
    required this.label,
    required this.value,
    this.destacado = false,
    this.valorGris = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
            color: destacado
                ? AppColors.primary
                : (valorGris ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _CardInfo extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final Widget? child;

  const _CardInfo({required this.icon, required this.titulo, this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (child != null) ...[
                    const SizedBox(height: 6),
                    child!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}