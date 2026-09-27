import 'package:flutter/material.dart';
import '../format/app_format.dart';
import '../theme/app_colors.dart';

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.amount,
    required this.currency,
    this.featured = false,
    this.categoryColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double amount;
  final String currency;
  final bool featured;
  final Color? categoryColor;
  final VoidCallback? onTap;

  String get formattedAmount {
    return AppFormat.moneda(amount, symbol: currency);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        featured ? AppColors.primary : (categoryColor ?? AppColors.primary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: featured ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: featured
              ? null
              : Border.all(
                  color: AppColors.borderSubtle,
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            // Icono
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: featured
                    ? AppColors.textOnPrimary.withValues(alpha: 0.2)
                    : effectiveColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: featured ? AppColors.textOnPrimary : effectiveColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: featured ? AppColors.textOnPrimary : null,
                ),
              ),
            ),
            // Monto
            Text(
              formattedAmount,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: featured ? AppColors.textOnPrimary : _amountColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _amountColor() {
    if (amount > 0) return AppColors.primary;
    if (amount < 0) return AppColors.coral;
    return AppColors.textSecondary;
  }
}
