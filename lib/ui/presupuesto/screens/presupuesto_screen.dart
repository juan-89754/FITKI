import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import 'presupuesto_categoria_form_screen.dart';
import '../widgets/mes_navigator.dart';
import '../widgets/presupuesto_categorias_view.dart';

/// Módulo de Presupuesto.
///
/// Un límite de gasto por categoría y mes. Lo gastado se calcula siempre desde
/// los movimientos reales, incluidos los pagos de gastos fijos, así que no hay
/// nada que registrar aquí dentro: la pantalla solo compara el plan con lo que
/// pasó y muestra en qué se está yendo la plata.
///
/// Los gastos fijos viven en su propio módulo: son lo que se repite cada mes,
/// no un plan de gasto, y mezclar los dos conceptos confundía más que ayudaba.
class PresupuestoScreen extends ConsumerWidget {
  const PresupuestoScreen({super.key});

  Future<void> _agregar(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PresupuestoCategoriaFormScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Presupuesto'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: const Column(
        children: [
          MesNavigator(),
          AvisoMesNoActual(
            texto: 'Estás viendo otro mes: el límite y el gasto que se muestran '
                'son los de ese período, no los de hoy.',
          ),
          Expanded(child: PresupuestoCategoriasView()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _agregar(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Presupuesto'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }
}
