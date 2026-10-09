import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppSnackbarType {
  success,
  error,
  warning,
  info,
}

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackbarType type = AppSnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = _getColors(context, type, scheme);

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getIcon(type),
            color: colors.foreground,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: colors.background,
      behavior: behavior,
      duration: duration,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: colors.foreground,
              onPressed: onAction,
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.border ?? colors.background.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snackBar);
  }

  static _SnackbarColors _getColors(
    BuildContext context,
    AppSnackbarType type,
    ColorScheme scheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case AppSnackbarType.success:
        return _SnackbarColors(
          background: isDark
              ? const Color(0xFF1F3128)
              : AppColors.mintPale.withValues(alpha: 0.95),
          foreground: isDark ? AppColors.textPrimary : const Color(0xFF0C3D2E),
          border: isDark ? const Color(0xFF2F4F3A) : AppColors.primary.withValues(alpha: 0.25),
        );
      case AppSnackbarType.error:
        return _SnackbarColors(
          background: isDark ? const Color(0xFF2F1A1A) : const Color(0xFFFDE8E8),
          foreground: isDark ? AppColors.textPrimary : const Color(0xFF5A1E1E),
          border: isDark ? const Color(0xFF3F2525) : AppColors.coral.withValues(alpha: 0.25),
        );
      case AppSnackbarType.warning:
        return _SnackbarColors(
          background: isDark ? const Color(0xFF2D2214) : const Color(0xFFFEF3E8),
          foreground: isDark ? AppColors.textPrimary : const Color(0xFF5A3A1A),
          border: isDark ? const Color(0xFF3A2C1B) : AppColors.orange.withValues(alpha: 0.25),
        );
      case AppSnackbarType.info:
        return _SnackbarColors(
          background: isDark ? const Color(0xFF1D2326) : AppColors.warmGray,
          foreground: isDark ? AppColors.textPrimary : AppColors.textPrimary,
          border: isDark ? const Color(0xFF2B2F31) : AppColors.borderSubtle,
        );
    }
  }

  static IconData _getIcon(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.success:
        return Icons.check_circle_outline_rounded;
      case AppSnackbarType.error:
        return Icons.error_outline_rounded;
      case AppSnackbarType.warning:
        return Icons.warning_amber_rounded;
      case AppSnackbarType.info:
        return Icons.info_outline_rounded;
    }
  }
}

class _SnackbarColors {
  final Color background;
  final Color foreground;
  final Color? border;

  const _SnackbarColors({
    required this.background,
    required this.foreground,
    this.border,
  });
}
