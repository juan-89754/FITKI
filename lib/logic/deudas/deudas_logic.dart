import 'dart:math';

import '../../data/models/debt.dart';

class DeudasLogic {
  /// Número aproximado de cuotas faltantes.
  /// - Sin cuota definida: `null`.
  /// - Sin tasa de interés: `ceil(pendiente / cuota)`.
  /// - Con tasa (anual %, convertida a mensual): fórmula estándar de
  ///   amortización. Devuelve `null` si la cuota no cubre los intereses.
  static int? cuotasRestantesAprox({
    required double montoPendiente,
    double? tasaInteresAnual,
    double? valorCuota,
  }) {
    if (valorCuota == null || valorCuota <= 0) return null;
    if (montoPendiente <= 0) return 0;

    final r = _tasaMensual(tasaInteresAnual);
    if (r <= 0) {
      return (montoPendiente / valorCuota).ceil();
    }

    if (r * montoPendiente >= valorCuota) {
      return null;
    }

    final n =
        -log(1 - (r * montoPendiente) / valorCuota) / log(1 + r);
    return n.ceil();
  }

  /// Monto inicial de la deuda (base para el progreso). Las deudas antiguas
  /// sin [Debt.montoInicial] usan su pendiente actual (progreso 0%).
  static double montoInicialOf(Debt deuda) {
    return deuda.montoInicial ?? deuda.montoPendiente;
  }

  /// Monto ya pagado de la deuda, nunca negativo.
  static double montoPagado(Debt deuda) {
    if (deuda.montoPendiente <= 0) return montoInicialOf(deuda);
    return (montoInicialOf(deuda) - deuda.montoPendiente)
        .clamp(0.0, double.infinity);
  }

  /// Progreso de pago en fracción 0-1 (1 = saldada).
  static double progresoPago(Debt deuda) {
    if (deuda.montoPendiente <= 0) return 1.0;
    final inicial = montoInicialOf(deuda);
    if (inicial <= 0) return 0.0;
    return montoPagado(deuda) / inicial;
  }

  static double _tasaMensual(double? tasaInteresAnual) {
    if (tasaInteresAnual == null || tasaInteresAnual <= 0) return 0;
    return pow(1 + tasaInteresAnual / 100, 1 / 12) - 1;
  }
}