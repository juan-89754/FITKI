import '../../data/models/quote.dart';
import '../../data/models/quote_item.dart';

class ComparacionCotizacion {
  final Quote cotizacion;
  final double total;

  /// `true` solo para la cotización con el menor total dentro de su proyecto.
  final bool esMasEconomica;

  const ComparacionCotizacion({
    required this.cotizacion,
    required this.total,
    required this.esMasEconomica,
  });
}

typedef CotizacionConItems = (Quote, List<QuoteItem>);

class CotizacionesLogic {
  /// Total de una cotización = Σ (cantidad * precio unitario + costos adicionales).
  static double totalCotizacion(List<QuoteItem> items) {
    return items.fold<double>(0, (acc, item) => acc + item.total);
  }

  /// Comparación entre cotizaciones de un mismo proyecto, ordenadas de
  /// menor a mayor total. La primera (más económica) se marca como tal.
  static List<ComparacionCotizacion> compararCotizaciones(
    List<CotizacionConItems> cotizaciones,
  ) {
    final ordenadas = cotizaciones
        .map((e) => ComparacionCotizacion(
              cotizacion: e.$1,
              total: totalCotizacion(e.$2),
              esMasEconomica: false,
            ))
        .toList()
      ..sort((a, b) => a.total.compareTo(b.total));

    if (ordenadas.isNotEmpty) {
      ordenadas[0] = ComparacionCotizacion(
        cotizacion: ordenadas[0].cotizacion,
        total: ordenadas[0].total,
        esMasEconomica: true,
      );
    }
    return ordenadas;
  }
}