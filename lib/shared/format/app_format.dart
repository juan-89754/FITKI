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