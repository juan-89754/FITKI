import 'dart:ui' show Color;

import 'package:fitki/shared/theme/app_colors.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Paleta de acentos', () {
    test('ofrece exactamente siete colores', () {
      expect(AppColors.acentos, hasLength(7));
    });

    test('arranca con el verde clásico como acento por defecto', () {
      expect(AppColors.acentoPorDefecto.nombre, 'Verde');
      expect(AppColors.acentoPorDefecto.primary, const Color(0xFF0C6E4E));
    });

    test('no repite nombres ni colores', () {
      final nombres = AppColors.acentos.map((a) => a.nombre).toSet();
      final colores = AppColors.acentos.map((a) => a.primary).toSet();
      expect(nombres, hasLength(AppColors.acentos.length));
      expect(colores, hasLength(AppColors.acentos.length));
    });

    // El color de marca es el fondo de las app bars, de los botones y del
    // bloque de saludo, y todos llevan texto blanco encima. Si un tono no
    // llega a 4.5:1 el usuario no puede leer nada, así que se fija la exigencia
    // por encima del mínimo (4.5:1) de WCAG AA.
    test('todos los acentos mantienen el texto blanco legible', () {
      for (final acento in AppColors.acentos) {
        expect(
          acento.contrasteConBlanco,
          greaterThanOrEqualTo(4.5),
          reason: '${acento.nombre} no alcanza el contraste mínimo con blanco',
        );
      }
    });

    test('excluye tonos demasiado claros para texto blanco', () {
      for (final acento in AppColors.acentos) {
        expect(
          acento.primary.computeLuminance(),
          lessThan(0.4),
          reason: '${acento.nombre} es demasiado claro',
        );
      }
    });
  });

  group('Tarjetas del inicio', () {
    tearDown(() {
      AppColors.acento = AppColors.acentoPorDefecto;
      AppColors.modo = ThemeMode.system;
    });

    // La barra del saludo de arriba ya usa el color de marca. Si la tarjeta
    // volviera a usarlo, ambas se fundirían en un solo plano: es el bug que se
    // reportó. El token es neutro justamente para que esto no dependa del
    // acento elegido.
    test('el fondo de las tarjetas nunca es el color de marca', () {
      for (final modo in [ThemeMode.light, ThemeMode.dark]) {
        AppColors.modo = modo;
        for (final acento in AppColors.acentos) {
          AppColors.acento = acento;
          expect(
            AppColors.destacado,
            isNot(acento.primary),
            reason: 'en ${modo.name} con ${acento.nombre} la tarjeta se '
                'fundiría con la barra de arriba',
          );
        }
      }
    });

    // El texto de las tarjetas es blanco, así que el fondo tiene que aguantarlo
    // en los dos modos y con cualquiera de los siete acentos.
    test('el texto blanco se lee sobre la tarjeta en ambos modos', () {
      for (final modo in [ThemeMode.light, ThemeMode.dark]) {
        AppColors.modo = modo;
        for (final acento in AppColors.acentos) {
          AppColors.acento = acento;
          final l = AppColors.destacado.computeLuminance();
          final contraste = 1.05 / (0.05 + l);
          expect(
            contraste,
            greaterThanOrEqualTo(4.5),
            reason: 'en ${modo.name} con ${acento.nombre} el contraste cae a '
                '${contraste.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    // En modo oscuro la tarjeta tiene que distinguirse del fondo de la página,
    // que es aún más oscuro.
    test('en modo oscuro la tarjeta se separa del fondo de la página', () {
      AppColors.modo = ThemeMode.dark;
      expect(
        AppColors.destacado.computeLuminance(),
        greaterThan(AppColors.background.computeLuminance()),
      );
    });

    // Y en claro tiene que distinguirse del fondo blanco de la página.
    test('en modo claro la tarjeta se separa del fondo de la página', () {
      AppColors.modo = ThemeMode.light;
      expect(
        AppColors.destacado.computeLuminance(),
        lessThan(AppColors.background.computeLuminance()),
      );
    });
  });

  group('Resolución del acento', () {
    test('devuelve el acento cuyo nombre coincide', () {
      expect(AppColors.acentoPorNombre('Azul'), AppColors.acentos[1]);
    });

    test('el nombre por defecto se resuelve al verde', () {
      expect(AppColors.acentoPorNombre(null), AppColors.acentoPorDefecto);
    });

    test('cae al acento por defecto si el nombre no existe', () {
      // Preference guardada por una versión posterior de la app.
      expect(AppColors.acentoPorNombre('Magenta'), AppColors.acentoPorDefecto);
    });
  });

  group('Los tokens siguen al acento', () {
    tearDown(() => AppColors.acento = AppColors.acentoPorDefecto);

    test('primary, mintPale y chipBackgroundPrimary cambian juntos', () {
      for (final acento in AppColors.acentos) {
        AppColors.acento = acento;
        expect(AppColors.primary, acento.primary);
        expect(AppColors.mintPale, acento.mint);
        expect(AppColors.chipBackgroundPrimary, acento.mint);
      }
    });

    test('la variante clara es más clara que su color de marca', () {
      for (final acento in AppColors.acentos) {
        AppColors.acento = acento;
        expect(
          acento.mint.computeLuminance(),
          greaterThan(acento.primary.computeLuminance()),
        );
      }
    });
  });
}
