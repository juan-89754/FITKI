import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../logic/gastos/periodo.dart';
import '../../../shared/theme/app_colors.dart';
import '../presupuesto_providers.dart';

/// Selector de mes del módulo. Es lo que antes no existía: el presupuesto solo
/// miraba el mes en curso, así que no había forma de revisar agosto ni de
/// planear el mes siguiente.
class MesNavigator extends ConsumerWidget {
  const MesNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoVisibleProvider);
    final esActual = periodo.esActual();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => ref
                .read(periodoVisibleProvider.notifier)
                .state = periodo.anterior,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Mes anterior',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                periodo.etiqueta,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              if (!esActual)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton(
                    onPressed: () => ref
                        .read(periodoVisibleProvider.notifier)
                        .state = Periodo.actual(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Hoy'),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: esActual
                ? null
                : () => ref
                      .read(periodoVisibleProvider.notifier)
                      .state = periodo.siguiente,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Mes siguiente',
          ),
        ],
      ),
    );
  }
}

/// Recuerda en qué mes se está mirando cuando no es el actual, para no
/// confundir los números de un período con los de hoy.
class AvisoMesNoActual extends ConsumerWidget {
  const AvisoMesNoActual({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoVisibleProvider);
    if (periodo.esActual()) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.chipBackgroundOrange,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        texto,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
