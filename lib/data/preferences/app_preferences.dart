import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias simples de la app (tema, color de marca, umbral de carga de
/// deuda y notificaciones): todo lo que no necesita tabla propia en SQLite.
///
/// Los accesos son métodos asíncronos tipados (no getters/setters síncronos)
/// porque la lectura/escritura depende de almacenamiento en disco.
///
/// Fitki no guarda ningún secreto: no hay PIN ni biometría, así que todo lo que
/// vive aquí son banderas de presentación y umbrales, no credenciales.
class AppPreferences {
  AppPreferences._();

  static const String _themeModeKey = 'config_theme_mode';
  static const String _colorPrincipalKey = 'config_color_principal';
  // Clave de una versión anterior que solo distinguía verde/rojo. Se lee una
  // vez para migrar y se borra al guardar el color nuevo.
  static const String _temaRojoKey = 'config_tema_rojo';
  static const String _nombreAcentoRojo = 'Rojo';
  static const String _umbralCargaDeudaKey = 'config_umbral_carga_deuda';
  static const String _notificacionesHabilitadasKey =
      'config_notificaciones_habilitadas';
  static const String _fechaUltimoBackupKey = 'config_fecha_ultimo_backup';

  /// Fracción de los ingresos mensuales a partir de la cual la carga de
  /// deuda se considera riesgosa por defecto (40%).
  static const double umbralCargaDeudaDefault = 0.40;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Modo de tema: 'system' | 'light' | 'dark'. Por defecto sigue al sistema.
  static Future<ThemeMode> getThemeMode() async {
    final value = (await _prefs()).getString(_themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode value) async {
    final prefs = await _prefs();
    await prefs.setString(_themeModeKey, value.name);
  }

  /// Color de marca elegido en Apariencia.
  ///
  /// Se guarda el identificador de [AcentoMarca] y no su índice, para que
  /// reordenar o ampliar la paleta no pierda la elección del usuario.
  ///
  /// Migra la preferencia anterior de acento rojo: quien la tenía activa pasa al
  /// rojo de la paleta nueva, y la clave vieja se descarta al guardar.
  static Future<String?> getColorPrincipal() async {
    final prefs = await _prefs();
    final guardado = prefs.getString(_colorPrincipalKey);
    if (guardado != null) return guardado;

    final eraRojo = prefs.getBool(_temaRojoKey) ?? false;
    return eraRojo ? _nombreAcentoRojo : null;
  }

  static Future<void> setColorPrincipal(String nombre) async {
    final prefs = await _prefs();
    await prefs.setString(_colorPrincipalKey, nombre);
    await prefs.remove(_temaRojoKey);
  }

  /// Fracción de los ingresos mensuales a partir de la cual la carga de
  /// deuda se considera riesgosa. Por defecto 0.40 (40%).
  static Future<double> getUmbralCargaDeuda() async {
    final prefs = await _prefs();
    return prefs.getDouble(_umbralCargaDeudaKey) ?? umbralCargaDeudaDefault;
  }

  static Future<void> setUmbralCargaDeuda(double value) async {
    final prefs = await _prefs();
    await prefs.setDouble(_umbralCargaDeudaKey, value);
  }

  /// Si la app emite recordatorios/notificaciones.
  static Future<bool> areNotificacionesHabilitadas() async {
    final prefs = await _prefs();
    return prefs.getBool(_notificacionesHabilitadasKey) ?? false;
  }

  static Future<void> setNotificacionesHabilitadas(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_notificacionesHabilitadasKey, value);
  }

  /// Fecha del último backup generado, o null si nunca se ha generado uno.
  static Future<DateTime?> getFechaUltimoBackup() async {
    final prefs = await _prefs();
    final valor = prefs.getString(_fechaUltimoBackupKey);
    return valor == null ? null : DateTime.tryParse(valor);
  }

  static Future<void> setFechaUltimoBackup(DateTime value) async {
    final prefs = await _prefs();
    await prefs.setString(_fechaUltimoBackupKey, value.toIso8601String());
  }
}