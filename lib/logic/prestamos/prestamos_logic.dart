import '../../data/models/loan.dart';

/// Lógica de negocio del módulo de préstamos a terceros.
///
/// Convenciones:
/// - `Loan.montoPagado` es la suma acumulada de pagos registrados contra el
///   préstamo (el repositorio la clampa para que nunca supere el monto
///   prestado).
/// - El estado se DERIVA siempre comparando pagos acumulados vs. monto
///   prestado; el campo `estado` guardado en BD queda sincronizado desde el
///   repositorio, pero nunca se usa como fuente para los cálculos.
class PrestamosLogic {
  /// Deriva el estado de un préstamo según sus pagos:
  ///
  ///   pagado_total    si montoPagado >= montoPrestado (margen ε por
  ///                   redondeo de números REAL en SQLite)
  ///   pagado_parcial  si 0 < montoPagado < montoPrestado
  ///   pendiente       si no se ha registrado ningún pago
  static String estadoPrestamo(double montoPrestado, double montoPagado) {
    const epsilon = 0.009;
    if (montoPagado + epsilon >= montoPrestado) return 'pagado_total';
    if (montoPagado > 0) return 'pagado_parcial';
    return 'pendiente';
  }

  static String estadoDe(Loan prestamo) =>
      estadoPrestamo(prestamo.montoPrestado, prestamo.montoPagado);

  /// Monto que aún falta por recibir del préstamo (nunca negativo).
  static double montoRestante(Loan prestamo) =>
      (prestamo.montoPrestado - prestamo.montoPagado)
          .clamp(0.0, double.infinity);

  /// Total que todavía falta por recibir de los préstamos no saldados: la suma
  /// de lo que RESTA cobrar de cada uno. No es la suma de lo prestado original,
  /// porque lo ya reembolsado ya volvió a la cuenta; contarlo mostraría como
  /// pendiente dinero que en realidad ya está de vuelta.
  static double totalPrestadoActivo(List<Loan> prestamos) {
    return prestamos
        .where((prestamo) => estadoDe(prestamo) != 'pagado_total')
        .fold<double>(0, (acumulado, prestamo) {
      return acumulado + montoRestante(prestamo);
    });
  }

  static const Map<String, String> _estadoLabels = {
    'pendiente': 'Pendiente',
    'pagado_parcial': 'Pago parcial',
    'pagado_total': 'Pagado',
  };

  static String labelEstado(String estado) => _estadoLabels[estado] ?? estado;
}