import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/categoria_personalizada.dart';
import 'package:fitki/data/providers/shared_providers.dart';
import 'package:fitki/ui/movimientos/screens/movimiento_form_screen.dart';
import 'package:fitki/ui/presupuesto/screens/gasto_fijo_form_screen.dart';

/// "Otro" dejó de apretujarse en la nota: al elegirlo aparece un campo propio
/// para nombrar la nueva categoría y la nota sigue siendo un campo aparte.
void main() {
  Future<void> pumpEn(WidgetTester tester, Widget pantalla) async {
    // Pantalla alta: el dropdown de categoría abre 11+ opciones y en el
    // viewport por defecto (800x600) el ítem "Otro" quedaría fuera y el tap
    // no lo acertaría.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activosStreamProvider.overrideWith(
            (ref) => Stream.value(const <Asset>[]),
          ),
          categoriasPersonalizadasStreamProvider.overrideWith(
            (ref) => Stream.value(const <CategoriaPersonalizada>[]),
          ),
        ],
        child: MaterialApp(home: pantalla),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> elegirOtro(WidgetTester tester) async {
    // Abre el dropdown de categoría y elige "Otro".
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otro').last);
    await tester.pumpAndSettle();
  }

  group('MovimientoFormScreen', () {
    testWidgets('al elegir Otro surge el campo de la nueva categoría',
        (tester) async {
      await pumpEn(tester, const MovimientoFormScreen());

      expect(find.byKey(const ValueKey('campo-categoria-otro')), findsNothing);

      await elegirOtro(tester);

      expect(
        find.byKey(const ValueKey('campo-categoria-otro')),
        findsOneWidget,
      );
      expect(find.text('Nombre de la categoría *'), findsOneWidget);
    });

    testWidgets('la nota sigue siendo un campo aparte, no se convierte en el '
        'nombre de la categoría', (tester) async {
      await pumpEn(tester, const MovimientoFormScreen());

      await elegirOtro(tester);

      await tester.scrollUntilVisible(
        find.text('Nota (opcional)'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nota (opcional)'), findsOneWidget);
    });
  });

  group('GastoFijoFormScreen', () {
    testWidgets('al elegir Otro surge el campo de la nueva categoría',
        (tester) async {
      await pumpEn(tester, const GastoFijoFormScreen());

      expect(find.byKey(const ValueKey('campo-categoria-otro')), findsNothing);

      await elegirOtro(tester);

      expect(
        find.byKey(const ValueKey('campo-categoria-otro')),
        findsOneWidget,
      );
      expect(find.text('Nombre de la categoría *'), findsOneWidget);
    });
  });
}