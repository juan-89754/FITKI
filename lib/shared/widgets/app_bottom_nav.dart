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

/// Barra de navegación inferior de la app.
///
/// Con 4 destinos entra completa en pantalla, así que no necesita carrusel ni
/// scroll: los items se reparten a lo ancho y la etiqueta nunca se recorta. El
/// contenedor sigue siendo un `GestureDetector` y no un `InkWell` porque la
/// píldora tiene bordes redondeados y no hay superficie Material debajo.
class AppBottomNav extends StatelessWidget {
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
          child: Row(
            children: List.generate(
              items.length,
              (index) => Expanded(
                child: _ItemNav(
                  item: items[index],
                  isActive: currentIndex == index,
                  onTap: () => onTap(index),
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
              padding: const EdgeInsets.symmetric(horizontal: 2),
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
