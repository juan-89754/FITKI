import 'package:intl/intl.dart';

class AppFormat {
  /// Formatea [valor] como moneda en pesos colombianos (es_CO).
  ///
  /// [decimales] controla la cantidad de decimales (0 por defecto: la app
  /// trabaja con pesos sin centavos, consistente en todos los módulos).
  /// [symbol] existe únicamente para el soporte multi-moneda del módulo de
  /// Activos (muestra 'US$' en cuentas en dólares y 'US$'/'$' según el
  /// activo); el resto de la app usa el símbolo por defecto '$'.
  static String moneda(
    double valor, {
    int decimales = 0,
    String symbol = r'$',
  }) {
    return NumberFormat.currency(
      locale: 'es_CO',
      symbol: symbol,
      decimalDigits: decimales,
    ).format(valor);
  }

  /// Formatea [valor] con el símbolo de su moneda. Solo el dólar tiene símbolo
  /// propio ('US$'); el resto de monedas se muestra con '$'.
  static String monedaPorCodigo(
    double valor,
    String codigo, {
    int decimales = 0,
  }) {
    final symbol = codigo == 'USD' ? 'US\$' : r'$';
    return moneda(valor, symbol: symbol, decimales: decimales);
  }

  /// Convierte un desglose por moneda en una línea de texto legible, p. ej.
  /// "$1.000 · US$2.000". Con una sola moneda es su monto directo; vacío,
  /// una cadena vacía.
  static String totalesEnLinea(Map<String, double> porMoneda) {
    if (porMoneda.isEmpty) return '';
    final renglones = porMoneda.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return renglones
        .map((e) => monedaPorCodigo(e.value, e.key))
        .join(' · ');
  }

  /// Texto con el que pre-llenar un campo de monto en modo edición: el mismo
  /// formato que produce [MilesInputFormatter] al escribir (dígitos agrupados
  /// con puntos de miles, sin decimales), p. ej. 150000.0 -> "150.000".
  ///
  /// Nunca pre-llenes con `toString()`/`toStringAsFixed(...)` crudos: sus
  /// decimales quedan pegados a los dígitos enteros ("150000.00") y al
  /// reformatear o parsear el monto termina multiplicado por 10/100.
  static String montoParaEditar(double valor) {
    return NumberFormat('#,##0', 'es_CO').format(valor);
  }
}