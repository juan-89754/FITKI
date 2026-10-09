import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppDialog {
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Aceptar',
    String cancelLabel = 'Cancelar',
    bool destructive = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            title,
            style: AppTypography.textTheme.titleLarge,
          ),
          content: Text(
            message,
            style: AppTypography.textTheme.bodyMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.borderSubtle,
              width: 1,
            ),
          ),
          surfaceTintColor: AppColors.surface,
          backgroundColor: AppColors.surface,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? AppColors.coral : AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  static Future<void> alert({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Aceptar',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            title,
            style: AppTypography.textTheme.titleLarge,
          ),
          content: Text(
            message,
            style: AppTypography.textTheme.bodyMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.borderSubtle,
              width: 1,
            ),
          ),
          surfaceTintColor: AppColors.surface,
          backgroundColor: AppColors.surface,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  static Future<void> info({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Entendido',
  }) async {
    await alert(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
  }
}
