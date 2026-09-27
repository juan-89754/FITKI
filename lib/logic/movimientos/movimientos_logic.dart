import '../../data/models/transaction.dart';

class TotalCategoria {
  final String categoria;
  final double total;

  const TotalCategoria({required this.categoria, required this.total});
}

class MovimientosLogic {
  static const String tipoIngreso = 'ingreso';
  static const String tipoGasto = 'gasto';

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

  static double totalDeTipo(List<Transaction> movimientos, String tipo) {
    double total = 0;
    for (final movimiento in movimientos) {
      if (movimiento.tipo == tipo) total += movimiento.monto;
    }
    return total;
  }

  static double totalIngresos(List<Transaction> movimientos) {
    return totalDeTipo(movimientos, tipoIngreso);
  }

  static double totalGastos(List<Transaction> movimientos) {
    return totalDeTipo(movimientos, tipoGasto);
  }

  static double balanceNeto(List<Transaction> movimientos) {
    return totalIngresos(movimientos) - totalGastos(movimientos);
  }
}