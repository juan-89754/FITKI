import '../../data/models/abono_meta.dart';
import '../../data/models/asset.dart';
import '../../data/models/investment.dart';

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
  /// Suma de los saldos **totales** por moneda: incluye el dinero apartado en
  /// metas, porque sigue siendo del usuario y sigue en la cuenta. Cada moneda
  /// va en su propia cuenta: sumarlas sin conversión sería mostrar como
  /// comparable dinero que no lo es.
  static Map<String, double> patrimonioTotalPorMoneda(List<Asset> activos) {
    final porMoneda = <String, double>{};
    for (final asset in activos) {
      porMoneda[asset.moneda] =
          (porMoneda[asset.moneda] ?? 0) + asset.montoDisponible;
    }
    return porMoneda;
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