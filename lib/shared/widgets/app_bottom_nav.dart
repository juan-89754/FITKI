import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const _kPillHeight = 72.0;
const _kPillBottomMargin = 14.0;
const _kPillHorizontalMargin = 14.0;
const _kActiveCircleSize = 44.0;

/// Ancho fijo de cada módulo en la barra.
///
/// Con los 11 módulos de la app la barra ya no entra en pantalla, así que no
/// puede repartir el ancho con `Expanded`: cada ítem mide lo mismo y el conjunto
/// se desliza. El ancho es el menor que deja leer "Configuración" y
/// "Estadísticas" completas en la etiqueta de 10px, que son las dos más largas.
const _kItemWidth = 84.0;

/// Barra de navegación inferior de la app.
///
/// Con 11 módulos la barra es un carrusel horizontal: entra lo que entra y el
/// resto se desliza con el dedo o con la barra misma. Cuando cambia el módulo —
/// porque se tocó un ítem o porque se arrastró el `PageView` de las pantallas—
/// la barra se reposa sola para dejar la pestaña activa a la vista; si no, al
/// volver de Configuración a Inicio el usuario no vería en qué está.
class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  final ScrollController _controller = ScrollController();

  /// Una clave por ítem para poder pedir que el scrollable lo revele.
  late List<GlobalKey> _claves = List.generate(
    widget.items.length,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    // La app puede abrir en un módulo que no sea el primero (enlace profundo o
    // restauración de estado), y en ese caso hay que dejar la barra ya posada.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revelarActiva());
  }

  @override
  void didUpdateWidget(AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != _claves.length) {
      _claves = List.generate(widget.items.length, (_) => GlobalKey());
    }
    if (widget.currentIndex != oldWidget.currentIndex) {
      // `ensureVisible` pide scroll a un RenderObject, y `didUpdateWidget`
      // corre en fase de build: hacerlo acá puede pedir layout antes de tiempo.
      // Se posterga al primer frame, que es cuando las claves ya tienen contexto.
      WidgetsBinding.instance.addPostFrameCallback((_) => _revelarActiva());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Desplaza la barra lo justo para que el módulo activo quede centrado.
  void _revelarActiva() {
    if (!mounted) return;
    final index = widget.currentIndex;
    if (index < 0 || index >= _claves.length) return;

    final contexto = _claves[index].currentContext;
    if (contexto == null) return;

    Scrollable.ensureVisible(
      contexto,
      alignment: 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Semantics(
      label: 'Barra de navegación inferior',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _kPillHorizontalMargin,
          0,
          _kPillHorizontalMargin,
          _kPillBottomMargin + bottomPadding,
        ),
        child: Container(
          height: _kPillHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Un `Row` dentro de un scroll horizontal en vez de `Expanded`: los 11
          // módulos no se reparten el ancho, se deslizan. La `Row` construye
          // todos sus hijos, así que las claves existen aunque el ítem esté fuera
          // de vista y `_revelarActiva` siempre puede encontrarlo.
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                widget.items.length,
                (index) => SizedBox(
                  key: _claves[index],
                  width: _kItemWidth,
                  child: _ItemNav(
                    item: widget.items[index],
                    isActive: widget.currentIndex == index,
                    onTap: () => widget.onTap(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  const _ItemNav({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final AppNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: _kActiveCircleSize,
              width: _kActiveCircleSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isActive)
                    Container(
                      width: _kActiveCircleSize,
                      height: _kActiveCircleSize,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  Icon(
                    item.icon,
                    color: isActive
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}