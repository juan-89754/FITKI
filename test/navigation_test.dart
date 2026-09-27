import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitki/main.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/debt.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/providers/shared_providers.dart';
import 'package:fitki/shared/widgets/app_bottom_nav.dart';
import 'package:fitki/shared/widgets/app_drawer.dart';
import 'package:fitki/ui/deudas/deudas_providers.dart';
import 'package:fitki/ui/metas/metas_providers.dart';
import 'package:fitki/ui/movimientos/movimientos_providers.dart';

/// Regresiones del sistema de navegación.
///
/// Regresan los tres síntomas reportados: la barra era un carrusel de 10
/// destinos que no entraban en pantalla, el botón atrás cerraba la app desde
/// cualquier pestaña, y los destinos se alcanzaban con verbos mezclados
/// (`goBranch`, `go` y `push` sobre raíces de rama) que rompían la linealidad.
Finder get barra => find.byType(AppBottomNav);

void main() {
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    router = buildRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activosStreamProvider.overrideWith(
            (ref) => Stream.value(const <Asset>[]),
          ),
          movimientosStreamProvider.overrideWith(
            (ref) => Stream.value(const <Transaction>[]),
          ),
          metasStreamProvider.overrideWith((ref) => Stream.value(const <FinancialGoal>[])),
          deudasStreamProvider.overrideWith((ref) => Stream.value(const <Debt>[])),
          perfilStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: FitkiApp(router: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('la barra muestra solo las 4 pestañas, sin carrusel', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final etiqueta in ['Inicio', 'Movimientos', 'Activos', 'Gastos']) {
      expect(
        find.descendant(of: barra, matching: find.text(etiqueta)),
        findsOneWidget,
        reason: 'la pestaña $etiqueta debe estar en la barra',
      );
    }

    // Los destinos que se movieron al menú lateral no pueden quedar duplicados
    // en la barra: era la causa del carrusel.
    for (final etiqueta in [
      'Deudas',
      'Estadísticas',
      'Cotizaciones',
      'Configuración',
      'Categorías',
      'Inversiones',
    ]) {
      expect(
        find.descendant(of: barra, matching: find.text(etiqueta)),
        findsNothing,
        reason: '$etiqueta ya no es una pestaña',
      );
    }

    // Sin carrusel: las 4 etiquetas se leen completas, sin scroll ni recorte.
    expect(
      find.byType(SingleChildScrollView),
      findsNothing,
      reason: 'la barra no debe tener scroll horizontal',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tocar una pestaña cambia de rama y conserva el estado', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.descendant(of: barra, matching: find.text('Activos')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/activos');

    // Volver a Inicio y regresar: la rama sigue en Activos, no se reinició.
    await tester.tap(find.descendant(of: barra, matching: find.text('Inicio')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: barra, matching: find.text('Activos')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/activos');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('atrás en una pestaña que no es Inicio vuelve a Inicio', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(of: barra, matching: find.text('Movimientos')),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/movimientos');

    // Este es el bug reportado: antes esto cerraba la app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(find.text('Este es el panorama de tus finanzas.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('atrás en Inicio no saca al usuario de la app', (tester) async {
    await pumpApp(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // canPop es true en Inicio, pero no hay nada que descartar en el stack: el
    // usuario se queda donde está en vez de cerrarse la app sin querer.
    expect(find.text('Este es el panorama de tus finanzas.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el menú lateral lista las secciones y las abre', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();

    final drawer = find.byType(AppDrawer);
    expect(drawer, findsOneWidget);

    for (final entrada in AppDrawer.destinos) {
      expect(
        find.descendant(of: drawer, matching: find.text(entrada.label)),
        findsOneWidget,
        reason: '${entrada.label} debe estar en el menú lateral',
      );
    }

    // Entrar a una sección la deja fuera del shell: sin barra inferior, así
    // el botón atrás tiene un significado inequívoco.
    await tester.tap(
      find.descendant(of: drawer, matching: find.text('Estadísticas')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(router.state.uri.path, '/estadisticas');
    // La sección cubre el shell: la barra sigue en el árbol pero ya no recibe
    // toques, que es justo lo que hace que el atrás sea inequívoco.
    expect(barra.hitTestable(), findsNothing);

    // Y atrás devuelve al punto exacto desde el que se salió.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(router.state.uri.path, '/');
    expect(barra, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
