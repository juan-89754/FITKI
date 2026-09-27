import '../../data/models/asset.dart';

class PatrimonioPorMoneda {
  final String moneda;
  final double total;

  const PatrimonioPorMoneda({required this.moneda, required this.total});
}

class ActivosLogic {
  static List<PatrimonioPorMoneda> calcularPatrimonioPorMoneda(
    List<Asset> activos,
  ) {
    final Map<String, double> totales = {};

    for (final asset in activos) {
      final moneda = asset.moneda;
      totales[moneda] = (totales[moneda] ?? 0) + asset.montoDisponible;
    }

    return totales.entries
        .map((e) => PatrimonioPorMoneda(moneda: e.key, total: e.value))
        .toList()
      ..sort((a, b) => a.moneda.compareTo(b.moneda));
  }

  static double calcularPatrimonioTotal(List<Asset> activos) {
    double total = 0;
    for (final asset in activos) {
      total += asset.montoDisponible;
    }
    return total;
  }
}