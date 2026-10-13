import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/gastos_fijos_tab.dart';
import '../widgets/mes_navigator.dart';
import 'gasto_fijo_form_screen.dart';

/// Módulo de Gastos fijos.
///
/// Las plantillas de lo que se paga todos los meses (internet, luz, arriendo).
/// La app genera sola la lista de lo que toca pagar cada mes, y al confirmar el
/// pago se crea el movimiento real que alimenta el presupuesto de su categoría.
///
/// Está separado del Presupuesto a propósito: un gasto fijo no es un plan de
/// gasto sino un compromiso recurrente, y cada uno tiene su propia lógica.
class GastosFijosScreen extends StatelessWidget {
  const GastosFijosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gastos fijos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: const Column(
        children: [
          MesNavigator(),
          AvisoMesNoActual(
            texto: 'Estás viendo otro mes: los pagos que se muestran son los de '
                'ese período, no los de hoy.',
          ),
          Expanded(child: GastosFijosTab()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GastoFijoFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Gasto fijo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }
}
