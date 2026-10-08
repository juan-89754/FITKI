import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'shared/theme/app_colors.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_providers.dart';
import 'shared/widgets/page_shell_container.dart';
import 'ui/home/home_screen.dart';
import 'ui/activos/screens/activos_screen.dart';
import 'ui/movimientos/screens/movimientos_screen.dart';
import 'ui/metas/screens/metas_screen.dart';
import 'ui/deudas/screens/deudas_screen.dart';
import 'ui/presupuesto/screens/presupuesto_screen.dart';
import 'ui/cotizaciones/screens/proyectos_screen.dart';
import 'ui/estadisticas/screens/estadisticas_screen.dart';
import 'ui/prestamos_inversiones/screens/prestamos_inversiones_screen.dart';
import 'ui/configuraciones/screens/perfil_screen.dart';
import 'ui/configuraciones/screens/configuraciones_screen.dart';
import 'ui/configuraciones/screens/backup_screen.dart';
import 'ui/configuraciones/screens/apariencia_screen.dart';
import 'ui/configuraciones/screens/categorias_screen.dart';

// Estructura de navegación de Fitki.
//
// El shell tiene 11 ramas: cada módulo de la app es una pestaña de la barra
// inferior y se llega a todas deslizando o tocando. Antes solo cuatro eran
// pestañas y las otras siete vivían en un menú lateral; ahora todas son ramas
// del mismo [StatefulShellRoute] y el menú desapareció.
//
// El contenedor de las ramas es un PageView (ver `PageShellContainer`), así que
// además de tocar la barra se puede pasar de módulo con el dedo. Cada rama
// conserva su Navigator, de modo que la posición de scroll y los filtros de
// cada módulo sobreviven al ida y vuelta.
//
// Regla de verbos:
//   - cambiar de módulo  -> navigationShell.goBranch (helper `irAModulo`)
//   - ir a una subpantalla de un módulo -> context.push (dentro de la rama)
//
// OJO con las rutas: go_router NO resuelve las rutas relativas contra la ruta
// actual, sino contra la raíz. `context.push('apariencia')` desde
// `/configuraciones` pide `/apariencia` y revienta con
// "GoException: no routes for location". Todas las rutas se escriben
// completas.
/// Router de la app. Es una función y no una constante para que los tests
/// puedan crear uno limpio por caso y no arrastrar el estado del anterior.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute(
      navigatorContainerBuilder:
          (context, navigationShell, children) => PageShellContainer(
            navigationShell: navigationShell,
            children: children,
          ),
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/movimientos',
              builder: (context, state) => const MovimientosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activos',
              builder: (context, state) => const ActivosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/gastos',
              builder: (context, state) => const PresupuestoScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/deudas',
              builder: (context, state) => const DeudasScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/metas',
              builder: (context, state) => const MetasScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/prestamos-inversiones',
              builder: (context, state) => const PrestamosInversionesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/estadisticas',
              builder: (context, state) => const EstadisticasScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cotizaciones',
              builder: (context, state) => const ProyectosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categorias',
              builder: (context, state) => const CategoriasScreen(),
            ),
          ],
        ),
        // Configuración es la única rama con hijas: Perfil, Backup y Apariencia
        // se apilan sobre su Navigator, así que el atrás devuelve a la lista y
        // no salta de módulo.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/configuraciones',
              builder: (context, state) => const ConfiguracionesScreen(),
              routes: [
                GoRoute(
                  path: 'perfil',
                  builder: (context, state) => const PerfilScreen(),
                ),
                GoRoute(
                  path: 'backup',
                  builder: (context, state) => const BackupScreen(),
                ),
                GoRoute(
                  path: 'apariencia',
                  builder: (context, state) => const AparienciaScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

final GoRouter _router = buildRouter();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  Intl.defaultLocale = 'es';

  // Fitki no tiene pantalla de bloqueo: entra directa al router, sin pedir PIN
  // ni biometría ni al arrancar ni al volver de segundo plano.
  runApp(const ProviderScope(child: FitkiApp()));
}

class FitkiApp extends ConsumerWidget {
  const FitkiApp({super.key, this.router});

  /// Permite inyectar un router propio (lo usan los tests de navegación).
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final acento =
        ref.watch(colorPrincipalProvider).valueOrNull ??
        AppColors.acentoPorDefecto;
    final brillo = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppColors.modo = switch (modo) {
      ThemeMode.dark => ThemeMode.dark,
      ThemeMode.light => ThemeMode.light,
      ThemeMode.system =>
        brillo == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    };
    AppColors.acento = acento;

    return MaterialApp.router(
      title: 'Fitki',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: modo,
      routerConfig: router ?? _router,
    );
  }
}
