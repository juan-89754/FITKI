import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences/app_preferences.dart';

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

class TemaRojoNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await AppPreferences.getTemaRojo();
    } catch (_) {
      // En entornos sin preferencias accesibles (p. ej. pruebas) no se usa
      // el acento rojo.
      return false;
    }
  }

  Future<void> cambiar(bool activo) async {
    state = AsyncValue.data(activo);
    try {
      await AppPreferences.setTemaRojo(activo);
    } catch (_) {
      // No se bloquea el cambio si la persistencia falla.
    }
  }
}

final temaRojoProvider = AsyncNotifierProvider<TemaRojoNotifier, bool>(
  TemaRojoNotifier.new,
);

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);