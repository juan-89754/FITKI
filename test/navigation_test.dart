import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitki/main.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/debt.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/abono_meta.dart';
import 'package:fitki/data/models/investment.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/providers/shared_providers.dart';
import 'package:fitki/data/models/perfil.dart';
import 'package:fitki/data/repositories/perfil_repository.dart';
import 'package:fitki/shared/widgets/app_bottom_nav.dart';
import 'package:fitki/shared/widgets/page_shell_container.dart';
import 'package:fitki/logic/carga_deuda.dart';
import 'package:fitki/ui/deudas/deudas_providers.dart';
import 'package:fitki/ui/home/home_screen.dart';
import 'package:fitki/ui/metas/metas_providers.dart';
import 'package:fitki/ui/movimientos/movimientos_providers.dart';
import 'package:fitki/ui/prestamos_inversiones/prestamos_inversiones_providers.dart';

/// Regresiones del sistema de navegación.
///
/// La app pasó de 4 pestañas + menú lateral a 11 módulos, todos en la barra
/// inferior y todos alcanzables deslizando. Lo que se vigila acá es lo que se
/// rompió en cada paso de ese cambio: que las etiquetas entren completas, que la
/// barra se desplace de verdad, que tocar un módulo change de rama y no apile
/// una pantalla encima de otra, y que el botón atrás siga llevando a Inicio
/// en vez de cerrar la app.
///
/// Los tests de UI no pueden recorrer los 11 módulos: cada uno monta su pantalla
/// y varias piden datos a la base, que no existe en `flutter test`. La lista
/// completa se verifica sobre el árbol de widgets (el `Row` de la barra construye
/// todos sus hijos, visibles o no) y el cambio de rama se comprueba con los
/// destinos que ya sabíamos montar.
Finder get barra => find.byType(AppBottomNav);

/// Los 11 módulos: etiqueta de la barra y ruta de la rama, en el orden de
/// `TabIndex`. Esta lista es la expectativa de dos cosas a la vez —el orden de
/// la barra y el orden de las ramas del router—, así que si alguien agrega un
/// módulo de un lado y no del otro, el test lo dice.
const _ramas = <(String, String)>[
  ('Inicio', '/'),
  ('Movimientos', '/movimientos'),
  ('Activos', '/activos'),
  ('Gastos', '/gastos'),
  ('Deudas', '/deudas'),
  ('Metas', '/metas'),
  ('Préstamos', '/prestamos-inversiones'),
  ('Estadísticas', '/estadisticas'),
  ('Cotizaciones', '/cotizaciones'),
  ('Categorías', '/categorias'),
  ('Configuración', '/configuraciones'),
];

/// Los destinos que se pueden montar en un test de widgets.
///
/// "Gastos" queda afuera a propósito: la pantalla lee `gastosFijosStreamProvider`,
/// `pagosGastosFijosStreamProvider`, `presupuestosActivosStreamProvider`,
/// `resumenesPresupuestoProvider` y tres providers más, todos sobre sqflite. Sin
/// base de datos real quedan promesas sin resolver y el test termina con timers
/// pendientes. Su ruta la cubre el test de ramas de abajo, que no necesita
/// montar nada.
const _montables = {'Inicio', 'Movimientos', 'Activos', 'Deudas', 'Configuración'};

Finder _scrollDeLaBarra() => find.descendant(
  of: barra,
  matching: find.byType(SingleChildScrollView),
);

Finder _etiqueta(String texto) =>
    find.descendant(of: barra, matching: find.text(texto));

/// PerfilRepository sin base de datos.
///
/// Las pantallas que leen en `initState` (como Perfil) llegan a sqflite, que
/// no está inicializado en `flutter test`. Este fake deja montar esas
/// pantallas para comprobar la navegación sin meter una base de datos real en
/// los tests de UI.
class _PerfilRepositoryFake extends PerfilRepository {
  Perfil? guardado;

  @override
  Future<Perfil?> obtenerUno() async => guardado;

  @override
  Future<List<Perfil>> getAll() async => [if (guardado != null) guardado!];

  @override
  Future<int> insert(Perfil perfil) async {
    guardado = perfil;
    return perfil.id ?? 1;
  }

  @override
  Future<int> update(Perfil perfil) async {
    guardado = perfil;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    guardado = null;
    return 1;
  }
}

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
          // Activos lo lee para mostrar las reservas de metas; sin el override
          // va a la base y el test cierra con timers pendientes.
          registrosDeMetasProvider.overrideWith(
            (ref) => Stream.value(const <AbonoMeta>[]),
          ),
          // Inicio y Activos también descuentan el capital reservado en
          // inversiones activas; sin el override van a la base y dejan timers
          // pendientes.
          inversionesStreamProvider.overrideWith(
            (ref) => Stream.value(const <Investment>[]),
          ),
          // Sin este override la pantalla de Deudas se queda girando: la carga
          // de deuda lee movimientos y umbral desde la base, y en `flutter test`
          // esa promesa no termina nunca, así que el `CircularProgressIndicator`
          // no para y `pumpAndSettle` no converge.
          cargaDeudaProvider.overrideWith((ref) async => calcularCargaDeuda(0, 0, umbral: 0)),
          perfilStreamProvider.overrideWith((ref) => Stream.value(null)),
          perfilRepositoryProvider.overrideWithValue(_PerfilRepositoryFake()),
          // El puente de registro rápido escucha las categorías del usuario
          // para armar los chips de la notificación, así que entra en el
          // grafo de la app igual que los streams de arriba.
        ],
        child: FitkiApp(router: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('la barra lista los 11 módulos sin recortes', (tester) async {
    await pumpApp(tester);

    for (final rama in _ramas) {
      expect(
        _etiqueta(rama.$1),
        findsOneWidget,
        reason: '${rama.$1} debe estar en la barra',
      );
    }

    // El menú hamburguesa ya no existe: los 7 módulos que vivían ahí son
    // pestañas ahora.
    expect(find.byTooltip('Abrir menú'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la barra se desliza y lleva el módulo activo a la vista', (
    tester,
  ) async {
    // Superficie de teléfono: con el ancho por defecto de los tests (800) los 11
    // módulos entrarían y no habría nada que deslizar.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);

    final scroll = _scrollDeLaBarra();
    expect(scroll, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(scroll).scrollDirection,
      Axis.horizontal,
      reason: 'la barra tiene que ser un carrusel horizontal',
    );

    // Los 11 módulos no entran: "Estadísticas" arranca fuera de la píldora.
    final barraRect = tester.getRect(barra);
    expect(
      tester.getRect(_etiqueta('Estadísticas')).left,
      greaterThan(barraRect.right),
      reason: 'sin barra deslizable, los 11 módulos no entrarían',
    );

    final antes = tester.getTopLeft(_etiqueta('Estadísticas')).dx;
    await tester.drag(scroll, const Offset(-400, 0));
    await tester.pumpAndSettle();
    final despues = tester.getTopLeft(_etiqueta('Estadísticas')).dx;
    expect(despues, lessThan(antes), reason: 'la barra tiene que desplazarse');

    // Al cambiar de módulo, la barra se reposa sola: al volver a Inicio, que
    // quedó al principio, "Inicio" tiene que volver a estar a la vista.
    await tester.ensureVisible(_etiqueta('Configuración'));
    await tester.pumpAndSettle();
    await tester.tap(_etiqueta('Configuración'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(_etiqueta('Configuración')).left,
      lessThan(barraRect.right),
      reason: 'la barra debe revelar la pestaña activa',
    );

    await tester.ensureVisible(_etiqueta('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(_etiqueta('Inicio'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(_etiqueta('Inicio')).left,
      greaterThanOrEqualTo(barraRect.left),
      reason: 'la barra debe volver a mostrar el módulo activo',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tocar un módulo cambia de rama y conserva el estado', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_etiqueta('Activos'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/activos');

    // Volver a Inicio y regresar: la rama sigue en Activos, no se reinició.
    await tester.tap(_etiqueta('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(_etiqueta('Activos'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/activos');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Un test por módulo. Antes iban todos en un solo `for`, y con que uno de los
// once se quedara cargando, el `pumpAndSettle` lanzaba y los otros diez
// aparecían como "no verificados" aunque estuvieran bien.
for (final etiqueta in _montables) {
  final ruta = _ramas.firstWhere((r) => r.$1 == etiqueta).$2;

  testWidgets('tocar $etiqueta abre $ruta sin apilar encima', (tester) async {
    await pumpApp(tester);
    expect(router.state.uri.path, '/');

    final finder = _etiqueta(etiqueta);

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    await tester.tap(finder);
    // Sin `pumpAndSettle`: hay pantallas con `CircularProgressIndicator` que no
    // paran nunca, y el timeout deja sin verificar nada. Al ruteo no le hace
    // falta esperar a la animación: `goBranch` ya resolvió la ruta.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Que la ruta sea exactamente la del módulo es lo que prueba que no se
    // apiló: con `context.push` la barra seguía marcando la pestaña anterior y
    // atrás volvía al lugar equivocado.
    expect(router.state.uri.path, ruta);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

// El orden de la barra y el de las ramas tienen que ser el mismo número: si no,
// tocar "Metas" lleva a Deudas y el `PageView` muestra la pantalla que no es.
// Este test no monta widgets, así que cubre los 11 módulos, incluso los que no
// se pueden levantar sin base de datos.
test('las 11 ramas del shell coinciden con los 11 módulos de la barra', () {
  final shell = buildRouter().configuration.routes
      .whereType<StatefulShellRoute>()
      .single;

  expect(shell.branches.length, 11);

  final rutasDeLasRamas = shell.branches
      .map((rama) => rama.routes.whereType<GoRoute>().first.path)
      .toList();

  expect(rutasDeLasRamas, _ramas.map((r) => r.$2).toList());
  expect(
    HomeShell.navItems.map((item) => item.label).toList(),
    _ramas.map((r) => r.$1).toList(),
    reason: 'la barra tiene que listar los módulos en el orden de las ramas',
  );
});

  testWidgets('deslizar el contenido cambia de módulo', (tester) async {
    await pumpApp(tester);

    expect(router.state.uri.path, '/');

    // El contenedor de las ramas es un PageView, así que arrastrar el cuerpo
    // cambia de módulo igual que tocar la barra.
    final contenido = find.byType(PageShellContainer);
    expect(contenido, findsOneWidget);

    // El gesto sale de la cabecera a propósito: en el centro de Inicio está el
    // carrusel horizontal de las categorías, que se queda con el arrastre, y
    // este test mediría el módulo equivocado.
    await tester.flingFrom(
      const Offset(400, 120),
      const Offset(-500, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/movimientos');

    // Y al revés, un arrastre a la derecha vuelve a Inicio.
    await tester.flingFrom(
      const Offset(400, 120),
      const Offset(500, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('atrás en un módulo que no es Inicio vuelve a Inicio', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_etiqueta('Movimientos'));
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

  // Las pantallas de Configuración son hijas de '/configuraciones'. Con rutas
  // relativas ('apariencia', 'backup'...) go_router las resolvía contra la
  // raíz y tiraba GoException: no routes for location, porque la subruta real
  // es '/configuraciones/apariencia'.
  const destinosConfiguracion = {
    // Etiqueta visible -> ruta esperada
    'Apariencia': '/configuraciones/apariencia',
    'Backup y restauración': '/configuraciones/backup',
    'Tu perfil': '/configuraciones/perfil',
  };

  for (final destino in destinosConfiguracion.entries) {
    testWidgets('Configuración abre "${destino.key}" en ${destino.value}', (
      tester,
    ) async {
      // La lista de Configuración es larga y el ListView solo construye lo que
      // entra en pantalla. Con la superficie por defecto (800x600) las últimas
      // tarjetas ni siquiera existen en el árbol y no se pueden tocar.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(tester);

      router.go('/configuraciones');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final etiqueta = find.text(destino.key);
      expect(etiqueta, findsOneWidget, reason: 'falta el destino visible');

      await tester.tap(etiqueta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        router.state.uri.path,
        destino.value,
        reason: 'tocar "${destino.key}" debe abrir ${destino.value}',
      );

      // Y atrás devuelve a la lista, no a otro módulo: las hijas se apilan
      // sobre el Navigator de su propia rama.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(router.state.uri.path, '/configuraciones');

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}