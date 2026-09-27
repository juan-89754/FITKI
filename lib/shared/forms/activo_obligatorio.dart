import 'package:flutter/material.dart';

import '../../data/models/asset.dart';
import '../theme/app_colors.dart';

/// Resuelve qué activo (cuenta) queda asociado a un gasto.
///
/// Es la regla única de la app: un gasto nunca se guarda sin activo, porque
/// el presupuesto se calcula sobre el dinero que sale de una cuenta concreta.
///
/// - Sin activos avisa que hay que crear uno primero y no deja seguir.
/// - Con un solo activo lo toma como valor por defecto, sin preguntar.
/// - Con varios y ninguno elegido, pregunta cuál es.
///
/// Devuelve el id del activo elegido, o null si el usuario canceló o no hay
/// activos disponibles.
Future<int?> resolverActivoDeGasto(
  BuildContext context, {
  required List<Asset> activos,
  int? actual,
}) async {
  if (activos.isEmpty) {
    await mostrarAviso(
      context,
      'Necesitas un activo',
      'Crea primero una cuenta o activo para poder registrar gastos. '
      'Todo gasto debe salir de una cuenta para que el presupuesto sume bien.',
    );
    return null;
  }

  if (actual != null && activos.any((a) => a.id == actual)) {
    return actual;
  }

  if (activos.length == 1) {
    return activos.first.id;
  }

  return _preguntarActivo(context, activos, actual);
}

Future<int?> _preguntarActivo(
  BuildContext context,
  List<Asset> activos,
  int? actual,
) async {
  final elegido = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('¿De qué cuenta salió el dinero?'),
      children: [
        for (final activo in activos)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, activo.id),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _iconoDeTipo(activo.tipo),
                color: AppColors.primary,
              ),
              title: Text(activo.nombre),
              subtitle: Text(
                activo.tipo,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              selected: activo.id == actual,
            ),
          ),
      ],
    ),
  );
  return elegido;
}

IconData _iconoDeTipo(String tipo) {
  switch (tipo) {
    case 'efectivo':
      return Icons.payments_rounded;
    case 'billetera_digital':
      return Icons.account_balance_wallet_rounded;
    case 'cuenta_bancaria':
      return Icons.account_balance_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Diálogo de aviso breve para los bloqueos de validación.
Future<void> mostrarAviso(
  BuildContext context,
  String titulo,
  String mensaje,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
