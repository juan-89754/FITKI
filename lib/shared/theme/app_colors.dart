import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Color, ThemeMode;

/// Un color de marca que el usuario puede elegir en Apariencia.
///
/// Todos los tonos son oscuros a propósito: el color de marca es el fondo de
/// las app bars, de los botones, del bloque de saludo del inicio y de las
/// fichas destacadas, y todos llevan texto blanco encima. [contrasteConBlanco]
/// documenta esa garantía y se verifica en `test/acentos_test.dart`.
///
/// Quedan fuera los tonos claros y los muy saturados: un amarillo o un naranja
/// brilliantes no soltarían el blanco y el usuario no podría leer nada.
@immutable
class AcentoMarca {
  const AcentoMarca(this.nombre, this.primary);

  /// Identificador estable con el que se persiste la elección. Se guarda el
  /// nombre y no el índice para que reordenar o ampliar la paleta no pierda lo
  /// que el usuario había elegido.
  final String nombre;

  /// Color de marca: app bars, botones, iconos y acentos.
  final Color primary;

  /// Variante clara para fondos de chips e iconos circulares.
  ///
  /// Se deriva de [primary] en vez de fijarse color por color, para que los
  /// siete acentos mantengan exactamente la misma relación con su fondo.
  Color get mint => Color.lerp(primary, const Color(0xFFFFFFFF), 0.88)!;

  /// Razón de contraste WCAG entre [primary] y el texto blanco que se apoya
  /// encima. Se publica para poder comprobarla en un test.
  double get contrasteConBlanco {
    final l = primary.computeLuminance();
    return 1.05 / (0.05 + l);
  }

  @override
  bool operator ==(Object other) =>
      other is AcentoMarca && other.nombre == nombre;

  @override
  int get hashCode => nombre.hashCode;

  @override
  String toString() => 'AcentoMarca($nombre)';
}

class AppColors {
  // Modo de color activo. Lo sincroniza FitkiApp con themeModeProvider
  // antes de construir la app, para que estos tokens se adapten en todo
  // el árbol (incluidas las pantallas que los usan directamente).
  static ThemeMode modo = ThemeMode.system;

  // Acento de marca elegido. Lo sincroniza FitkiApp con colorPrincipalProvider.
  static AcentoMarca acento = acentoPorDefecto;

  static bool get esOscuro {
    final m = modo;
    if (m == ThemeMode.dark) return true;
    if (m == ThemeMode.light) return false;
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  // Colores de marca que no cambian entre modos ni acentos
  static const Color coral = Color(0xFFDA4F4F);
  static const Color orange = Color(0xFFF4A65F);
  static const Color oliveGreen = Color(0xFF6E6C4F);
  static const Color grayOlive = Color(0xFF888780);
  static const Color warmGray = Color(0xFFF1EFE8);

  // Variantes claras para fondos de chips/íconos (fijas)
  static const Color chipBackgroundCoral = Color(0xFFFDE8E8);
  static const Color chipBackgroundOrange = Color(0xFFFEF3E8);
  static const Color chipBackgroundOlive = Color(0xFFEEEDE8);

  // ---- Paleta de marca elegible ----
  // Siete tonos, todos con el blanco por encima de 5:1 de contraste. Se ordenan
  // de forma que ningún par se confunda: verde (el histórico), azul, turquesa,
  // ámbar, rojo, rosa y púrpura.
  static const AcentoMarca acentoPorDefecto = AcentoMarca(
    'Verde',
    Color(0xFF0C6E4E),
  );

  static const List<AcentoMarca> acentos = [
    acentoPorDefecto,
    AcentoMarca('Azul', Color(0xFF1D4E89)),
    AcentoMarca('Turquesa', Color(0xFF0F6C7A)),
    AcentoMarca('Ámbar', Color(0xFFB45309)),
    AcentoMarca('Rojo', Color(0xFFB0301F)),
    AcentoMarca('Rosa', Color(0xFFA61E63)),
    AcentoMarca('Púrpura', Color(0xFF6D28D9)),
  ];

  /// Resuelve un acento por su identificador. Un nombre desconocido (por
  /// ejemplo, una preferencia guardada por una versión posterior) cae al
  /// acento por defecto en lugar de dejar la app sin color de marca.
  static AcentoMarca acentoPorNombre(String? nombre) {
    if (nombre == null) return acentoPorDefecto;
    for (final opcion in acentos) {
      if (opcion.nombre == nombre) return opcion;
    }
    return acentoPorDefecto;
  }

  // Colores de marca (siguen al acento seleccionado)
  static Color get primary => acento.primary;
  static Color get mintPale => acento.mint;
  static Color get chipBackgroundPrimary => acento.mint;

  // Paleta oscura — grises neutros con tinte verde muy sutil
  static const Color _backgroundDark = Color(0xFF121212);
  static const Color _surfaceDark = Color(0xFF1E2022);
  static const Color _surfaceSecondaryDark = Color(0xFF252829);
  static const Color _inputBackgroundDark = Color(0xFF252829);
  static const Color _textPrimaryDark = Color(0xFFECF0ED);
  static const Color _textSecondaryDark = Color(0xFF9BA3A0);
  static const Color _borderDark = Color(0xFF3A3D3E);
  static const Color _borderSubtleDark = Color(0xFF2C2F30);

  // Fondo de las tres tarjetas del inicio (Movimientos, Metas y Deudas).
  //
  // Neutro a propósito, y no un tinte del acento: los siete colores de marca
  // son saturados, así que cualquier tinte derivado de ellos competiría con la
  // barra de color de arriba, que es justo lo que pasaba cuando la tarjeta
  // iba en color de marca. Un gris profundo no depende de la elección del
  // usuario, contrasta siempre con la barra del saludo y mantiene el texto
  // blanco por encima de 13:1 en ambos modos.
  static const Color _destacadoClaro = Color(0xFF1B1F1E);
  static const Color _destacadoOscuro = Color(0xFF2B302E);

  // Fondos y superficies (adaptativos)
  static Color get background => esOscuro ? _backgroundDark : const Color(0xFFFFFFFF);
  static Color get surface => esOscuro ? _surfaceDark : const Color(0xFFFFFFFF);
  static Color get surfaceSecondary => esOscuro ? _surfaceSecondaryDark : warmGray;
  static Color get inputBackground => esOscuro ? _inputBackgroundDark : warmGray;

  // Texto
  static Color get textPrimary => esOscuro ? _textPrimaryDark : const Color(0xFF1A1A1A);
  static Color get textSecondary => esOscuro ? _textSecondaryDark : grayOlive;
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Bordes
  static Color get border => esOscuro ? _borderDark : const Color(0xFFE8E5E0);
  static Color get borderSubtle => esOscuro ? _borderSubtleDark : warmGray;

  // Tarjeta que destaca sobre el resto (la de Movimientos en el inicio).
  static Color get destacado => esOscuro ? _destacadoOscuro : _destacadoClaro;

  // Paleta para gráficas (colores adicionales de acento)
  static const List<Color> paletaGraficas = [
    Color(0xFF5A8FB4),
    Color(0xFF8E6BA7),
    Color(0xFFB47A5A),
  ];

  // Overlays sobre superficies de color
  static const Color overlayLight = Color(0x33FFFFFF);
}
