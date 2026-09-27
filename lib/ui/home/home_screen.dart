// Navegación principal de Fitki usando go_router.
// El HomeShell agrupa las 4 pestañas en un StatefulShellRoute y mantiene el
// AppBottomNav fijo. El resto de módulos se alcanzan desde el menú lateral,
// que empuja secciones por encima del shell.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/format/app_format.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/category_tile.dart';
import '../../data/models/financial_goal.dart';
import '../../data/models/transaction.dart';
import '../../data/models/perfil.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/categorias/categoria_labels.dart';
import '../../logic/metas/metas_logic.dart';
import '../configuraciones/widgets/perfil_avatar.dart';
import '../movimientos/movimientos_providers.dart';
import '../activos/activos_providers.dart';
import '../deudas/deudas_providers.dart';
import '../metas/metas_providers.dart';
import 'tab_navigation.dart';

/// Salta a la pestaña de Movimientos. Se usa `goBranch` y no `context.go`
/// porque el destino es una rama del shell: así se preserva el scroll y los
/// filtros con los que se había dejado esa pestaña.
void irAMovimientos(BuildContext context) {
  StatefulNavigationShell.of(context).goBranch(TabIndex.movimientos);
}

class _ShellDrawerScope extends InheritedWidget {
  const _ShellDrawerScope({
    required this.openDrawer,
    required super.child,
  });

  /// Abre el menú lateral del shell. Vive en un scope porque los headers de
  /// cada pantalla cuelgan de su propio `Scaffold`, y ahí `Scaffold.of`
  /// resuelve al anidado (que no tiene drawer) en vez del que lo tiene.
  final VoidCallback openDrawer;

  @override
  bool updateShouldNotify(_ShellDrawerScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<AppNavItem> navItems = [
    AppNavItem(icon: Icons.home_rounded, label: 'Inicio'),
    AppNavItem(icon: Icons.swap_horiz_rounded, label: 'Movimientos'),
    AppNavItem(icon: Icons.account_balance_rounded, label: 'Activos'),
    AppNavItem(icon: Icons.savings_rounded, label: 'Gastos'),
  ];

  /// Comportamiento de la barra:
  /// - Otra pestaña -> cambia de rama preservando el estado de cada una.
  /// - La misma pestaña y con scroll -> sube al principio con animación.
  /// - La misma pestaña y ya arriba -> reinicia esa rama.
  void _onSeleccionar(BuildContext context, WidgetRef ref, int index) {
    if (index != navigationShell.currentIndex) {
      navigationShell.goBranch(index);
      return;
    }

    final controller = ref.read(tabScrollControllersProvider)[index];
    if (controller.hasClients && controller.offset > 0) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    navigationShell.goBranch(index, initialLocation: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enInicio = navigationShell.currentIndex == TabIndex.inicio;

    return PopScope(
      // Solo se deja salir de la app desde Inicio. En el resto de pestañas el
      // botón atrás lleva a Inicio, así la app nunca se cierra por sorpresa.
      canPop: enInicio,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        navigationShell.goBranch(TabIndex.inicio);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AppDrawer(),
        body: Builder(
          builder: (shellBodyContext) => _ShellDrawerScope(
            openDrawer: () => Scaffold.of(shellBodyContext).openDrawer(),
            child: navigationShell,
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => _onSeleccionar(context, ref, index),
          items: navItems,
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static String _moneda(double valor) => AppFormat.moneda(valor);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final patrimonio = ref.watch(patrimonioTotalProvider);
    final movimientosAsync = ref.watch(movimientosStreamProvider);
    final metas =
        ref.watch(metasStreamProvider).asData?.value ?? const <FinancialGoal>[];
    final deudasActivas = ref.watch(deudasActivasProvider);
    final perfil = ref.watch(perfilStreamProvider).asData?.value;

    final movimientos =
        movimientosAsync.asData?.value ?? const <Transaction>[];
    final query = _busqueda.trim().toLowerCase();
    final visibles = query.isEmpty
        ? movimientos
        : movimientos.where((movimiento) {
            final texto = (
              '${movimiento.categoria} '
              '${labelCategoria(movimiento.categoria)} '
              '${movimiento.nota ?? ''}'
            ).toLowerCase();
            return texto.contains(query);
          }).toList();
    final ultimos = visibles.take(4).toList();

    final metasTotal = metas
        .where((meta) => !MetasLogic.calcular(meta).cumpleObjetivo)
        .fold<double>(0, (acc, meta) => acc + meta.montoAhorrado);
    final deudasPendiente =
        deudasActivas.fold<double>(0, (acc, deuda) => acc + deuda.montoPendiente);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        controller: ref.read(tabScrollControllersProvider)[TabIndex.inicio],
        padding: EdgeInsets.zero,
        children: [
          _Header(
            patrimonio: patrimonio,
            saludo: _saludo(),
            perfil: perfil,
          ),
          _Categorias(
            metasTotal: metasTotal,
            deudasPendiente: deudasPendiente,
          ),
          _BarraBusqueda(
            controller: _busquedaController,
            onChanged: (valor) => setState(() => _busqueda = valor),
          ),
          _UltimosMovimientos(
            movimientos: ultimos,
            hayCargando: movimientosAsync.isLoading,
            buscando: query.isNotEmpty,
            query: _busqueda.trim(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.patrimonio,
    required this.saludo,
    this.perfil,
  });

  final double patrimonio;
  final String saludo;
  final Perfil? perfil;

  String _greeting() {
    final nombre = perfil?.nombre.trim();
    if (nombre == null || nombre.isEmpty) return '$saludo,';
    return '$saludo, $nombre';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 36),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      // El recorte evita que los círculos decorativos se salgan del bloque
      // verde: antes se cortaban contra el borde de la lista y se leían como un
      // ícono incompleto junto al saludo.
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Decoración en la mitad baja, lejos de la fila del saludo: ahí el
          // espacio está libre y el texto se lee sin nada detrás.
          Positioned(
            left: -46,
            top: 104,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -34,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // El menú va a la izquierda y el avatar se queda en la
                  // esquina superior derecha. Ambos miden 44 para que queden
                  // alineados al mismo eje.
                  IconButton(
                    onPressed:
                        context
                            .dependOnInheritedWidgetOfExactType<
                              _ShellDrawerScope
                            >()
                            ?.openDrawer,
                    tooltip: 'Abrir menú',
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(44),
                      minimumSize: const Size.square(44),
                      maximumSize: const Size.square(44),
                      backgroundColor: AppColors.textOnPrimary.withValues(
                        alpha: 0.15,
                      ),
                    ),
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.textOnPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge!.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textOnPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Este es el panorama de tus finanzas.',
                          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontSize: 13,
                            color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  PerfilAvatar(
                    nombre: perfil?.nombre ?? '',
                    fotoPath: perfil?.fotoPath,
                    size: 44,
                    onTap: () => context.push('/configuraciones/perfil'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'PATRIMONIO TOTAL',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  letterSpacing: 1.2,
                  color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                HomeScreen._moneda(patrimonio),
                style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Categorias extends StatefulWidget {
  const _Categorias({
    required this.metasTotal,
    required this.deudasPendiente,
  });

  final double metasTotal;
  final double deudasPendiente;

  @override
  State<_Categorias> createState() => _CategoriasState();
}

class _CategoriasState extends State<_Categorias> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              itemCount: 3,
              onPageChanged: (index) => setState(() => _currentPage = index),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final categories = [
                  (
                    label: 'Movimientos',
                    icon: Icons.swap_horiz_rounded,
                    amount: 0.0,
                    onTap: () => irAMovimientos(context),
                  ),
                  (
                    label: 'Metas',
                    icon: Icons.flag_rounded,
                    amount: widget.metasTotal,
                    onTap: () => context.push('/metas'),
                  ),
                  (
                    label: 'Deudas',
                    icon: Icons.account_balance_wallet_rounded,
                    amount: widget.deudasPendiente,
                    onTap: () => context.push('/deudas'),
                  ),
                ];
                final cat = categories[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: CategoryTile(
                    label: cat.label,
                    icon: cat.icon,
                    amount: cat.amount,
                    currency: r'$',
                    onTap: cat.onTap,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppColors.primary
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraBusqueda extends StatelessWidget {
  const _BarraBusqueda({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.titleSmall,
        decoration: InputDecoration(
          hintText: 'Buscar movimientos por categoría o nota…',
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.grayOlive,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: AppColors.surfaceSecondary,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _UltimosMovimientos extends StatelessWidget {
  const _UltimosMovimientos({
    required this.movimientos,
    required this.hayCargando,
    this.buscando = false,
    this.query = '',
  });

  final List<Transaction> movimientos;
  final bool hayCargando;
  final bool buscando;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Últimos movimientos',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => irAMovimientos(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  'Ver todos',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (hayCargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (movimientos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    buscando
                        ? Icons.search_off_rounded
                        : Icons.receipt_long_rounded,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    buscando
                        ? 'Sin resultados para "$query".'
                        : 'Aún no hay movimientos registrados.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...movimientos.map(
              (movimiento) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FilaUltimoMovimiento(
                  movimiento: movimiento,
                  onTap: () => irAMovimientos(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaUltimoMovimiento extends StatelessWidget {
  const _FilaUltimoMovimiento({required this.movimiento, required this.onTap});

  final Transaction movimiento;
  final VoidCallback onTap;

  bool get _esIngreso => movimiento.tipo == 'ingreso';
  Color get _color => _esIngreso ? AppColors.primary : AppColors.coral;

  @override
  Widget build(BuildContext context) {
    final fechaFormateada =
        DateFormat('dd MMM yyyy').format(movimiento.fecha);
    final signo = _esIngreso ? '+' : '-';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _esIngreso
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: _color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelCategoria(movimiento.categoria),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fechaFormateada,
                      style: Theme.of(context).textTheme.bodySmall!,
                    ),
                  ],
                ),
              ),
              Text(
                '$signo${HomeScreen._moneda(movimiento.monto)}',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}