import '../../data/models/transaction.dart';

class TotalCategoria {
  final String categoria;
  final double total;

  const TotalCategoria({required this.categoria, required this.total});
}

class MovimientosLogic {
  static const String tipoIngreso = 'ingreso';
  static const String tipoGasto = 'gasto';

  /// Clave bajo la que se agrupan los movimientos cuya moneda no se puede
  /// resolver (sin activo, o con un activo ya eliminado). Nunca se suman a la
  /// de una moneda real: se muestran aparte.
  static const String monedaDesconocida = 'sin_moneda';

  static List<TotalCategoria> totalesPorCategoria(
    List<Transaction> movimientos, {
    String? tipo,
  }) {
    final Map<String, double> acumulador = {};
    for (final movimiento in movimientos) {
      if (tipo != null && movimiento.tipo != tipo) continue;
      final actual = acumulador[movimiento.categoria] ?? 0;
      acumulador[movimiento.categoria] = actual + movimiento.monto;
    }

    final totales = acumulador.entries
        .map((e) => TotalCategoria(categoria: e.key, total: e.value))
        .toList();
    totales.sort((a, b) => b.total.compareTo(a.total));
    return totales;
  }

  /// Totales de los movimientos de [tipo] agrupados por la moneda del activo
  /// al que pertenecen ([monedaDe] mapea `activoId` a su código). Los
  /// movimientos sin activo resoluble caen bajo [monedaDesconocida].
  static Map<String, double> totalesDeTipo(
    List<Transaction> movimientos,
    String tipo,
    Map<int?, String> monedaDe,
  ) {
    final porMoneda = <String, double>{};
    for (final movimiento in movimientos) {
      if (movimiento.tipo != tipo) continue;
      final moneda = monedaDe[movimiento.activoId] ?? monedaDesconocida;
      porMoneda[moneda] = (porMoneda[moneda] ?? 0) + movimiento.monto;
    }
    return porMoneda;
  }

  static Map<String, double> totalIngresos(
    List<Transaction> movimientos,
    Map<int?, String> monedaDe,
  ) {
    return totalesDeTipo(movimientos, tipoIngreso, monedaDe);
  }

  static Map<String, double> totalGastos(
    List<Transaction> movimientos,
    Map<int?, String> monedaDe,
  ) {
    return totalesDeTipo(movimientos, tipoGasto, monedaDe);
  }

  /// Balance por moneda a partir de los ingresos y gastos ya agrupados. Cada
  /// moneda se resta solo contra sí misma.
  static Map<String, double> balanceNeto(
    Map<String, double> ingresos,
    Map<String, double> gastos,
  ) {
    final porMoneda = <String, double>{};
    for (final moneda in {...ingresos.keys, ...gastos.keys}) {
      porMoneda[moneda] = (ingresos[moneda] ?? 0) - (gastos[moneda] ?? 0);
    }
    return porMoneda;
  }
}