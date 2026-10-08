import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Índices de los módulos de la barra inferior. El orden es el mismo que el de
/// las ramas del [StatefulShellRoute] en `main.dart`: si cambiás una rama,
/// cambiá la constante acá.
abstract final class TabIndex {
  static const inicio = 0;
  static const movimientos = 1;
  static const activos = 2;
  static const gastos = 3;
  static const deudas = 4;
  static const metas = 5;
  static const prestamos = 6;
  static const estadisticas = 7;
  static const cotizaciones = 8;
  static const categorias = 9;
  static const configuracion = 10;

  static const total = 11;
}

/// Salta al módulo [index] de la barra.
///
/// Antes cada módulo era una ruta suelta y se entraba con `context.push`, que
/// apila la pantalla sobre la rama actual en vez de cambiar de rama: se veía el
/// módulo nuevo pero la barra seguía marcando el anterior y el atrás volvía al
/// lugar equivocado. Ahora que todos son ramas, el verbo correcto es
/// [StatefulNavigationShell.goBranch], que además preserva el estado de cada
/// rama.
void irAModulo(BuildContext context, int index) {
  StatefulNavigationShell.of(context).goBranch(index);
}

/// Un [ScrollController] por pestaña.
///
/// Permite que tocar la pestaña que ya está activa la lleve al principio con
/// una animación corta, en vez de reiniciarla de golpe. Los controladores
/// viven en un provider para sobrevivir a los rebuilds del shell: así, al
/// volver a una pestaña se conserva el scroll donde estaba y el gesto de
/// "tocar para subir" sigue teniendo sentido.
class TabScrollControllers {
  TabScrollControllers()
    : items = List.generate(TabIndex.total, (_) => ScrollController());

  final List<ScrollController> items;

  ScrollController operator [](int index) => items[index];

  void dispose() {
    for (final controller in items) {
      controller.dispose();
    }
  }
}

final tabScrollControllersProvider = Provider<TabScrollControllers>((ref) {
  final controllers = TabScrollControllers();
  ref.onDispose(controllers.dispose);
  return controllers;
});
