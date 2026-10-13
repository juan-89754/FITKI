import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fila de "etiqueta: valor" de las tarjetas de detalle.
///
/// [destacado] resalta el valor (negrita) y lo pinta con [destacadoColor]
/// (o el color primario); [valorGris] lo deja en gris para datos secundarios.
class DetalleFila extends StatelessWidget {
  const DetalleFila({
    super.key,
    required this.label,
    required this.value,
    this.destacado = false,
    this.valorGris = false,
    this.destacadoColor,
  });

  final String label;
  final String value;
  final bool destacado;
  final bool valorGris;
  final Color? destacadoColor;

  @override
  Widget build(BuildContext context) {
    final color = destacado
        ? (destacadoColor ?? AppColors.primary)
        : (valorGris ? AppColors.textSecondary : AppColors.textPrimary);
    final estilo = Theme.of(context).textTheme.titleSmall!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: estilo.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: estilo.copyWith(
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
