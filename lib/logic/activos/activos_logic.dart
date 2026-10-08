import '../../data/models/abono_meta.dart';
import '../../data/models/asset.dart';
import '../../data/models/investment.dart';

class PatrimonioPorMoneda {
  final String moneda;
  final double total;

  const PatrimonioPorMoneda({required this.moneda, required this.total});
}

/// Cada activo maneja dos saldos, y esta es la única regla que los define:
///
/// - **Saldo Total** (`Asset.montoDisponible`): todo el dinero que hay en la
///   cuenta. Solo lo mueven ingresos y gastos reales.
/// - **Saldo Disponible**: la parte de ese total que el usuario todavía puede
///   gastar. La diferencia entre ambos es el dinero reservado en metas.
///
/// Un aporte a una meta NO baja el Saldo Total: el dinero sigue en la cuenta,
/// pasa a "reservado". Un retiro lo hace pasar de vuelta a disponible. Por eso
/// el saldo de un activo nunca se desincroniza de su historial de movimientos:
/// las metas solo afectan la disponibilidad, nunca el saldo real.
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

  /// Dinero de [activoId] que está reservado en metas: la suma con signo de
  /// todos sus registros (aporta, resta).
  ///
  /// [registros] son los de todos los abonos de la app, no solo los de una
  /// meta: el dinero reservado sale de una cuenta, así que se agrega por cuenta
  /// y no por meta.
  static double saldoReservadoEn(
    int? activoId,
    List<AbonoMeta> registros,
  ) {
    if (activoId == null) return 0;
    double reservado = 0;
    for (final registro in registros) {
      if (registro.activoId == activoId) {
        reservado += registro.montoConSigno;
      }
    }
    return reservado;
  }

  /// Dinero de [activoId] que está reservado en inversiones activas. Se calcula
  /// a partir del capital derivado de cada inversión ([Investment.montoInvertido]).
  /// Una inversión finalizada ya liberó su capital, así que no cuenta.
  static double saldoReservadoInversionesEn(
    int? activoId,
    List<Investment> inversiones,
  ) {
    if (activoId == null) return 0;
    double reservado = 0;
    for (final inversion in inversiones) {
      if (inversion.activoId == activoId && inversion.estaActiva) {
        reservado += inversion.montoInvertido;
      }
    }
    return reservado;
  }

  /// Saldo Disponible de un activo: lo que queda libre para gastar.
  ///
  /// Puede quedar en cero (o incluso ser menor que cero si el saldo total ya
  /// venía en negativo) pero nunca se "arregla" con un piso: el número que ve el
  /// usuario tiene que ser el que sale de la cuenta, no uno recortado que hide
  /// que ya no alcanza.
  static double saldoDisponible(
    double saldoTotal,
    double reservado, {
    double reservadoInversiones = 0,
  }) {
    return saldoTotal - reservado - reservadoInversiones;
  }
}