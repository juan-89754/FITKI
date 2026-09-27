import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/preferences/app_preferences.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_providers.dart';
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
import 'ui/configuraciones/screens/seguridad_screen.dart';
import 'ui/configuraciones/screens/categorias_screen.dart';
import 'ui/seguridad/screens/lock_screen.dart';

// Estructura de navegación de Fitki.
//
// El shell tiene SOLO 4 ramas (las cuatro pestañas de la barra inferior) y
// preserva el estado de cada una. Todo lo demás (Deudas, Préstamos e
// inversiones, Estadísticas, Cotizaciones, Metas, Categorías y
// Configuración) son secciones que se empujan por encima del shell desde el
// menú lateral: al entrar se ocultan la barra y el menú, y el botón atrás
// devuelve exactamente al punto desde el que se entró.
//
// Regla de verbos:
//   - cambiar de pestaña  -> navigationShell.goBranch
//   - entrar a una sección -> context.push (destino fuera del shell)
//   - ir a una subpantalla -> context.push con ruta RELATIVA
/// Router de la app. Es una función y no una constante para que los tests
/// puedan crear uno limpio por caso y no arrastrar el estado del anterior.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
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
      ],
    ),

    // Secciones del menú lateral: fuera del shell a propósito, para que la
    // barra inferior no quede flotando sobre ellas y el atrás sea coherente.
    GoRoute(
      path: '/deudas',
      builder: (context, state) => const DeudasScreen(),
    ),
    GoRoute(
      path: '/prestamos-inversiones',
      builder: (context, state) => const PrestamosInversionesScreen(),
    ),
    GoRoute(
      path: '/estadisticas',
      builder: (context, state) => const EstadisticasScreen(),
    ),
    GoRoute(
      path: '/cotizaciones',
      builder: (context, state) => const ProyectosScreen(),
    ),
    GoRoute(
      path: '/metas',
      builder: (context, state) => const MetasScreen(),
    ),
    GoRoute(
      path: '/categorias',
      builder: (context, state) => const CategoriasScreen(),
    ),
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
        GoRoute(
          path: 'seguridad',
          builder: (context, state) => const SeguridadScreen(),
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

  // Si el PIN está habilitado, la app arranca bloqueada: se muestra primero
  // la pantalla de bloqueo y, al desbloquear, se monta el router principal.
  var pinActivo = false;
  try {
    pinActivo = await AppPreferences.isPinHabilitado();
  } catch (_) {
    // Sin preferencias accesibles la app abre sin bloqueo.
  }

  runApp(ProviderScope(child: AppGate(pinActivo: pinActivo)));
}

/// Puerta de entrada de la app. Si el bloqueo con PIN está activo, [LockScreen]
/// se superpone a toda la app al arrancar y cada vez que la app vuelve de
/// segundo plano, exigiendo el PIN antes de continuar en el punto donde el
/// usuario estaba.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key, required this.pinActivo});

  final bool pinActivo;

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate>
    with WidgetsBindingObserver {
  /// true mientras el PIN esté cubriendo la app (arranque o al volver de
  /// segundo plano).
  bool _bloqueado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloqueado = widget.pinActivo;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // La app se va a segundo plano (paused) o pierde el foco (inactive): se
    // deja el bloqueo pendiente para exigir el PIN al volver. Si el usuario
    // nunca activó el PIN, isPinHabilitado es false y no se bloquea.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _rearmarBloqueo();
    }
  }

  Future<void> _rearmarBloqueo() async {
    if (_bloqueado) return;
    try {
      final activo = await AppPreferences.isPinHabilitado();
      if (!activo || _bloqueado || !mounted) return;
      setState(() => _bloqueado = true);
    } catch (_) {
      // Sin preferencias accesibles no hay PIN configurado: no se bloquea.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FitkiApp(
      bloqueado: _bloqueado,
      onDesbloqueado: () => setState(() => _bloqueado = false),
    );
  }
}

class FitkiApp extends ConsumerWidget {
  const FitkiApp({
    super.key,
    this.bloqueado = false,
    this.onDesbloqueado,
    this.router,
  });

  /// Mientras sea true, [LockScreen] cubre toda la app (la navegación debajo
  /// queda montada, de modo que al desbloquear se continúa donde se estaba).
  final bool bloqueado;

  /// Se invoca cuando el PIN o la biometría verifican correctamente.
  final VoidCallback? onDesbloqueado;

  /// Permite inyectar un router propio (lo usan los tests de navegación).
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final rojo = ref.watch(temaRojoProvider).valueOrNull ?? false;
    final brillo = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppColors.modo = switch (modo) {
      ThemeMode.dark => ThemeMode.dark,
      ThemeMode.light => ThemeMode.light,
      ThemeMode.system =>
        brillo == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    };
    AppColors.acentoRojo = rojo;

    return MaterialApp.router(
      title: 'Fitki',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: modo,
      routerConfig: router ?? _router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (bloqueado)
              LockScreen(
                onDesbloqueado: () => onDesbloqueado?.call(),
              ),
          ],
        );
      },
    );
  }
}