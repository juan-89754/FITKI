import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/material.dart' show Color, ThemeMode;

class AppColors {
  // Modo de color activo. Lo sincroniza FitkiApp con themeModeProvider
  // antes de construir la app, para que estos tokens se adapten en todo
  // el árbol (incluidas las pantallas que los usan directamente).
  static ThemeMode modo = ThemeMode.system;

  // Acento alternativo "Rojo": el color de marca pasa de verde a rojo sin
  // cambiar los fondos (sigue siendo el tema claro). Lo sincroniza FitkiApp
  // con temaRojoProvider.
  static bool acentoRojo = false;

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

  // ---- Paletas de marca ----
  // Verde (clásico)
  static const Color _primaryVerde = Color(0xFF0C6E4E);
  static const Color _mintVerde = Color(0xFFE2ECE8);
  static const Color _chipVerde = Color(0xFFE2ECE8);
  // Rojo (acento alternativo). Suficiente contraste para botones/appbars con
  // texto blanco y distinguible del coral usado para los egresos.
  static const Color _primaryRojo = Color(0xFFB0301F);
  static const Color _mintRojo = Color(0xFFFBE4E0);
  static const Color _chipRojo = Color(0xFFFBE4E0);

  // Colores de marca (siguen al acento seleccionado)
  static Color get primary => acentoRojo ? _primaryRojo : _primaryVerde;
  static Color get mintPale => acentoRojo ? _mintRojo : _mintVerde;
  static Color get chipBackgroundGreen => acentoRojo ? _chipRojo : _chipVerde;

  // Paleta oscura — grises neutros con tinte verde muy sutil
  static const Color _backgroundDark = Color(0xFF121212);
  static const Color _surfaceDark = Color(0xFF1E2022);
  static const Color _surfaceSecondaryDark = Color(0xFF252829);
  static const Color _inputBackgroundDark = Color(0xFF252829);
  static const Color _textPrimaryDark = Color(0xFFECF0ED);
  static const Color _textSecondaryDark = Color(0xFF9BA3A0);
  static const Color _borderDark = Color(0xFF3A3D3E);
  static const Color _borderSubtleDark = Color(0xFF2C2F30);

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

  // Paleta para gráficas (colores adicionales de acento)
  static const List<Color> paletaGraficas = [
    Color(0xFF5A8FB4),
    Color(0xFF8E6BA7),
    Color(0xFFB47A5A),
  ];

  // Overlays sobre superficies de color
  static const Color overlayLight = Color(0x33FFFFFF);
}