import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias simples de la app (tema, umbral de carga de deuda, seguridad
/// y notificaciones): todo lo que no necesita tabla propia en SQLite.
///
/// Los accesos son métodos asíncronos tipados (no getters/setters síncronos)
/// porque la lectura/escritura depende de almacenamiento en disco/Keychain.
///
/// POR QUÉ EL PIN SE GUARDA CON flutter_secure_storage Y NO CON
/// shared_preferences:
///
/// `shared_preferences` persiste los valores como texto plano en archivos
/// locales del dispositivo (preferences.xml en Android, UserDefaults en
/// iOS). Un respaldo, una copia del dispositivo o una app con acceso a esos
/// archivos podría leerlos directamente. Aunque el PIN se conserve como hash,
/// un PIN es un secreto de baja entropía (4-6 dígitos, ~10.000 combinaciones)
/// y un hash offline se puede revertir por fuerza bruta en segundos, sobre
/// todo si se usa un algoritmo rápido o falta una sal aleatoria.
///
/// `flutter_secure_storage`, en cambio, delega el cifrado al sistema del
/// dispositivo:
///  - Android: las claves y valores se cifran con material criptográfico
///    generado en Android Keystore (claves RSA/AES que no salen del entorno
///    protegido del sistema).
///  - iOS/macOS: usa el Keychain de Apple, que cifra los datos y protege el
///    secreto a nivel de sistema.
///  - Permite además proteger la lectura con biometría: el valor solo se
///    descifra tras autenticar al usuario.
///
/// Regla que seguimos: cualquier secreto relacionado con la seguridad (el
/// hash del PIN) vive en `flutter_secure_storage`; lo no sensible (tema,
/// umbral, banderas) va a `shared_preferences`.
class AppPreferences {
  AppPreferences._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _themeModeKey = 'config_theme_mode';
  static const String _temaRojoKey = 'config_tema_rojo';
  static const String _umbralCargaDeudaKey = 'config_umbral_carga_deuda';
  static const String _pinHabilitadoKey = 'config_pin_habilitado';
  static const String _pinHashKey = 'config_pin_hash';
  static const String _biometriaHabilitadaKey = 'config_biometria_habilitada';
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

  /// Si el acento de marca es rojo (en lugar del verde clásico). El modo rojo
  /// se muestra sobre el tema claro: cambia solo los colores de marca.
  static Future<bool> getTemaRojo() async {
    final prefs = await _prefs();
    return prefs.getBool(_temaRojoKey) ?? false;
  }

  static Future<void> setTemaRojo(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_temaRojoKey, value);
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

  /// Si el desbloqueo de la app exige introducir el PIN.
  static Future<bool> isPinHabilitado() async {
    final prefs = await _prefs();
    return prefs.getBool(_pinHabilitadoKey) ?? false;
  }

  static Future<void> setPinHabilitado(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_pinHabilitadoKey, value);
  }

  /// Hash del PIN. Se guarda CIFRADO con `flutter_secure_storage`, nunca en
  /// `shared_preferences` (ver explicación al inicio de esta clase).
  static Future<String?> getPinHashSeguro() async {
    return _secureStorage.read(key: _pinHashKey);
  }

  static Future<void> setPinHashSeguro(String? value) async {
    if (value == null) {
      await _secureStorage.delete(key: _pinHashKey);
    } else {
      await _secureStorage.write(key: _pinHashKey, value: value);
    }
  }

  /// Si además del PIN se permite desbloquear con biometría.
  static Future<bool> isBiometriaHabilitada() async {
    final prefs = await _prefs();
    return prefs.getBool(_biometriaHabilitadaKey) ?? false;
  }

  static Future<void> setBiometriaHabilitada(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_biometriaHabilitadaKey, value);
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