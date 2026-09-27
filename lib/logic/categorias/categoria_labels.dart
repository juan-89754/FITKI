import 'package:flutter/material.dart';

import '../../data/models/categoria_personalizada.dart';

/// Categorías de GASTO predefinidas (slugs internos que se guardan en los
/// movimientos y presupuestos). Fuente única de la lista fija que presentan
/// los dropdowns de categoría de gasto.
const List<String> categoriasGasto = [
  'alimentacion',
  'transporte',
  'vivienda',
  'servicios',
  'educacion',
  'salud',
  'entretenimiento',
  'ropa',
  'tecnologia',
  'pagos',
  'otro',
];

/// Categorías de INGRESO predefinidas (slugs internos). Fuente única de la
/// lista fija que presenta el dropdown de categoría de ingreso.
const List<String> categoriasIngreso = [
  'salario',
  'freelance',
  'ventas',
  'inversiones',
  'regalos',
  'otro',
];

/// Valor reservado al que se reasignan los movimientos y gastos presupuestados
/// que usaban una categoría personalizada recién borrada. El historial no se
/// pierde ni rompe: aparece como "Categoría eliminada" en las pantallas.
const String categoriaEliminada = 'categoria_eliminada';

/// Finalidades de metas conocidas por la app.
const List<String> finalidades = [
  'viaje',
  'emergencia',
  'vivienda',
  'vehiculo',
  'educacion',
  'tecnologia',
  'otro',
];

final Map<String, String> _categoriaLabels = {
  'salario': 'Salario',
  'freelance': 'Freelance',
  'ventas': 'Ventas',
  'inversiones': 'Inversiones',
  'regalos': 'Regalos',
  'alimentacion': 'Alimentación',
  'transporte': 'Transporte',
  'vivienda': 'Vivienda',
  'servicios': 'Servicios',
  'educacion': 'Educación',
  'salud': 'Salud',
  'entretenimiento': 'Entretenimiento',
  'ropa': 'Ropa',
  'tecnologia': 'Tecnología',
  'pagos': 'Pagos de deuda',
  'otro': 'Otro',
  categoriaEliminada: 'Categoría eliminada',
};

final Map<String, IconData> _categoriaIconos = {
  'alimentacion': Icons.restaurant_rounded,
  'servicios': Icons.electrical_services_rounded,
  'transporte': Icons.directions_bus_rounded,
  'vivienda': Icons.home_rounded,
  'educacion': Icons.school_rounded,
  'salud': Icons.local_hospital_rounded,
  'entretenimiento': Icons.movie_rounded,
  'ropa': Icons.checkroom_rounded,
  'tecnologia': Icons.devices_rounded,
  'pagos': Icons.payments_rounded,
  'salario': Icons.attach_money_rounded,
  'freelance': Icons.work_rounded,
  'ventas': Icons.point_of_sale_rounded,
  'inversiones': Icons.trending_up_rounded,
  'regalos': Icons.card_giftcard_rounded,
  'otro': Icons.category_rounded,
  categoriaEliminada: Icons.delete_outline_rounded,
};

final Map<String, String> _finalidadLabels = {
  'viaje': 'Viaje',
  'emergencia': 'Fondo de emergencia',
  'vivienda': 'Vivienda',
  'vehiculo': 'Vehículo',
  'educacion': 'Educación',
  'tecnologia': 'Tecnología',
  'otro': 'Otro',
};

/// Etiqueta legible para una categoría de movimiento/gasto.
///
/// Los slugs predefinidos se traducen (p. ej. 'alimentacion' → 'Alimentación').
/// Cualquier otro valor corresponde a una categoría personalizada y se muestra
/// con su nombre tal como se guardó, o como "Categoría eliminada" si dejó de
/// existir.
String labelCategoria(String categoria) {
  return _categoriaLabels[categoria] ?? categoria;
}

/// Icono para una categoría de movimiento/gasto. Las categorías personalizadas
/// no guardan su ícono en cada movimiento (solo el nombre), así que se usa el
/// ícono genérico; las eliminadas muestran un ícono de borrado.
IconData iconoCategoria(String categoria) {
  return _categoriaIconos[categoria] ?? Icons.category_rounded;
}

/// Etiqueta legible para una finalidad de meta; 'Otro' si es desconocida.
String labelFinalidad(String finalidad) {
  return _finalidadLabels[finalidad] ?? 'Otro';
}

/// Categorías de un tipo listas para un dropdown: las predefinidas seguidas
/// de las personalizadas del usuario (solo las de ese tipo, por su nombre,
/// que es el valor que queda guardado en el movimiento/presupuesto).
/// Si una personalizada repite el nombre de una fija (ignorando mayúsculas)
/// se omite, para no romper la asociación nombre→slug.
List<String> categoriasDeTipo(
  String tipo,
  List<CategoriaPersonalizada> personalizadas,
) {
  final fijas = tipo == 'ingreso' ? categoriasIngreso : categoriasGasto;
  final resultado = List<String>.of(fijas);
  for (final personalizada in personalizadas) {
    if (personalizada.tipo != tipo) continue;
    final duplicada = resultado.any(
      (fija) => fija.toLowerCase() == personalizada.nombre.toLowerCase(),
    );
    if (!duplicada) resultado.add(personalizada.nombre);
  }
  return resultado;
}