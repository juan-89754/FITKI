import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Índices de las 4 pestañas de la barra inferior. El orden es el mismo que el
/// de las ramas del [StatefulShellRoute] en `main.dart`: si cambiás una rama,
/// cambiá la constante acá.
abstract final class TabIndex {
  static const inicio = 0;
  static const movimientos = 1;
  static const activos = 2;
  static const gastos = 3;

  static const total = 4;
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
