import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static TextTheme get textTheme {
    const manropeMedium = TextStyle(
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w500,
    );
    const interRegular = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
    );
    const interMedium = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w500,
    );

    return TextTheme(
      headlineLarge: manropeMedium.copyWith(
        fontSize: 32,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      headlineMedium: manropeMedium.copyWith(
        fontSize: 24,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      titleLarge: manropeMedium.copyWith(
        fontSize: 20,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      titleMedium: interMedium.copyWith(
        fontSize: 16,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      titleSmall: interMedium.copyWith(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodyLarge: interMedium.copyWith(
        fontSize: 16,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: interRegular.copyWith(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      bodySmall: interRegular.copyWith(
        fontSize: 12,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      labelLarge: interMedium.copyWith(
        fontSize: 14,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      labelSmall: interRegular.copyWith(
        fontSize: 11,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
    );
  }
}
