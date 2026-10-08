import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor de las ramas del [StatefulShellRoute] basado en un [PageView].
///
/// La variante `.indexedStack` que usaba la app muestra una sola rama a la vez
/// con un `IndexedStack`, así que no hay forma de cambiar de módulo deslizando
/// el dedo. Este contenedor reemplaza esa pieza por un carrusel horizontal.
///
/// La sincronización va en los dos sentidos, y es la parte que el ejemplo
/// oficial de go_router no cubre: ahí solo se escucha `onPageChanged`, con lo
/// cual tocar una pestaña del carrusel mueve la rama pero la pantalla no
/// acompaña. Acá, cuando el índice cambia por fuera del gesto (tocar un ítem de
/// la barra, un salto por enlace profundo o el botón atrás), el `PageView`
/// persigue al índice con [didUpdateWidget].
class PageShellContainer extends StatefulWidget {
  const PageShellContainer({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  /// El shell cuyas ramas se están mostrando.
  final StatefulNavigationShell navigationShell;

  /// Un Navigator por rama, en el mismo orden que las ramas declaradas.
  final List<Widget> children;

  @override
  State<PageShellContainer> createState() => _PageShellContainerState();
}

class _PageShellContainerState extends State<PageShellContainer> {
  late final PageController _controller = PageController(
    initialPage: widget.navigationShell.currentIndex,
  );

  /// Índice de la página que el carrusel tiene delante ahora mismo.
  ///
  /// Se usa `round()` a propósito: mientras el dedo arrastra, `page` es un valor
  /// fraccionario y compararlo con el índice exacto daría una diferencia
  /// siempre, animando el carrusel mientras el propio gesto lo mueve.
  int get _indiceVisible {
    if (!_controller.hasClients) return widget.navigationShell.currentIndex;
    return (_controller.page ?? 0).round();
  }

  void _irA(int index) {
    if (!_controller.hasClients) return;
    final actual = _indiceVisible;
    if (actual == index) return;

    // Un salto de más de una página no se anima: recorrer diez páginas con un
    // mismo gesto se siente como un glitch. Con la barra de 11 módulos eso pasa
    // cada vez que se elige uno del principio o del final.
    if ((index - actual).abs() > 1) {
      _controller.jumpToPage(index);
      return;
    }

    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(PageShellContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `didUpdateWidget` corre en fase de build y tanto `jumpToPage` como
    // `animateToPage` notifican listeners de forma síncrona: hacerlo acá dispara
    // "setState() or markNeedsBuild() called during build" en el `Router` de
    // go_router. Se posterga al primer frame, cuando ya se puede tocar el
    // controlador del `PageView`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _irA(widget.navigationShell.currentIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      // El gesto manda sobre el índice: cada rama tiene su Navigator y su
      // posición de scroll, y el `PageView` solo las muestra.
      onPageChanged: (index) => widget.navigationShell.goBranch(index),
      children: widget.children,
    );
  }
}