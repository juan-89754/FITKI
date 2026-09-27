import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences/app_preferences.dart';
import 'app_colors.dart';

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    try {
      return await AppPreferences.getThemeMode();
    } catch (_) {
      // En entornos sin preferencias accesibles (p. ej. pruebas) se usa
      // el modo del sistema.
      return ThemeMode.system;
    }
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = AsyncValue.data(modo);
    try {
      await AppPreferences.setThemeMode(modo);
    } catch (_) {
      // No se bloquea el cambio si la persistencia falla.
    }
  }
}

class ColorPrincipalNotifier extends AsyncNotifier<AcentoMarca> {
  @override
  Future<AcentoMarca> build() async {
    try {
      return AppColors.acentoPorNombre(await AppPreferences.getColorPrincipal());
    } catch (_) {
      // En entornos sin preferencias accesibles (p. ej. pruebas) se queda el
      // verde clásico.
      return AppColors.acentoPorDefecto;
    }
  }

  Future<void> cambiar(AcentoMarca acento) async {
    state = AsyncValue.data(acento);
    try {
      await AppPreferences.setColorPrincipal(acento.nombre);
    } catch (_) {
      // No se bloquea el cambio si la persistencia falla.
    }
  }
}

final colorPrincipalProvider =
    AsyncNotifierProvider<ColorPrincipalNotifier, AcentoMarca>(
      ColorPrincipalNotifier.new,
    );

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);