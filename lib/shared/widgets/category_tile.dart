import 'package:flutter/material.dart';
import '../format/app_format.dart';
import '../theme/app_colors.dart';

/// Tarjeta del carrusel de inicio (Metas, Deudas, Inversiones y Patrimonio).
///
/// Todas comparten exactamente el mismo aspecto: un fondo neutro profundo
/// con texto blanco. No se tiñen con el color de marca ni con un color por
/// tarjeta, porque el bloque de arriba ya usa el acento de la app y cualquier
/// color saturado en la tarjeta se fundía con él. La información se distingue
/// por el ícono y el monto, no por el fondo; y la tarjeta central del carrusel
/// ya se comunica con el tamaño, que es la de verdad.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.amount,
    required this.currency,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double amount;
  final String currency;
  final VoidCallback? onTap;

  String get formattedAmount {
    return AppFormat.moneda(amount, symbol: currency);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.destacado,
          borderRadius: BorderRadius.circular(16),
          // Borde en blanco al 12% en vez de en el color de marca: separa la
          // tarjeta del fondo de la página sin introducir un segundo tono.
          border: Border.all(
            color: AppColors.textOnPrimary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textOnPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedAmount,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                // Al 75% para que el monto acompañe sin competir con el
                // nombre. Sigue siendo blanco, así que no depende del acento.
                color: AppColors.textOnPrimary.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
