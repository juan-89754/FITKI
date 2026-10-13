import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Estado vacío reutilizable para listas y pestañas: un ícono en un círculo,
/// un título, una descripción y una acción opcional.
///
/// Centraliza el estilo que antes repetía cada pantalla en su propio
/// `_EstadoVacio`, para que todas se vean igual.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.etiquetaAccion,
    this.onAccion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;

  /// Texto del botón. Si es `null` (o [onAccion] también), no se muestra botón.
  final String? etiquetaAccion;
  final VoidCallback? onAccion;

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
              child: Icon(icono, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: AppColors.textSecondary),
            ),
            if (onAccion != null && etiquetaAccion != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAccion,
                icon: const Icon(Icons.add_rounded),
                label: Text(etiquetaAccion!),
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
          ],
        ),
      ),
    );
  }
}
