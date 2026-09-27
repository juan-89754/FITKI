import '../../data/models/asset.dart';
import '../../data/models/transaction.dart';
import '../../data/models/financial_goal.dart';
import '../../data/models/debt.dart';

class GastoCategoria {
  final String categoria;
  final double total;
  final double porcentaje;

  const GastoCategoria({
    required this.categoria,
    required this.total,
    required this.porcentaje,
  });
}

class PuntoEvolucion {
  final DateTime fecha;
  final double valor;

  const PuntoEvolucion({required this.fecha, required this.valor});
}

class ProgresoMetas {
  final int totalMetas;
  final int conObjetivo;
  final double promedio;

  const ProgresoMetas({
    required this.totalMetas,
    required this.conObjetivo,
    required this.promedio,
  });
}

class EstadisticasDatos {
  final double patrimonioTotal;
  final double balanceMes;
  final double ingresosMes;
  final double gastosMes;
  final List<GastoCategoria> gastosPorCategoria;
  final List<PuntoEvolucion> evolucionPatrimonio;
  final ProgresoMetas? progresoMetas;
  final double totalDeudasPendientes;
  /// Suma de las cuotas mensuales de las deudas activas (base de la "carga
  /// de deuda", distinta del total pendiente).
  final double totalCuotasMensuales;

  const EstadisticasDatos({
    required this.patrimonioTotal,
    required this.balanceMes,
    required this.ingresosMes,
    required this.gastosMes,
    required this.gastosPorCategoria,
    required this.evolucionPatrimonio,
    required this.progresoMetas,
    required this.totalDeudasPendientes,
    required this.totalCuotasMensuales,
  });
}

class EstadisticasLogic {
  static const int mesesEvolucion = 6;

  static bool _esDelMes(DateTime fecha, DateTime referencia) {
    return fecha.year == referencia.year && fecha.month == referencia.month;
  }

  /// Distribución de gastos por categoría en el mes actual, ordenada de
  /// mayor a menor total, con su porcentaje respecto al total gastado.
  static List<GastoCategoria> distribucionGastosPorCategoria(
    List<Transaction> movimientos, {
    DateTime? fechaReferencia,
  }) {
    final referencia = fechaReferencia ?? DateTime.now();
    final Map<String, double> acumulador = {};
    for (final movimiento in movimientos) {
      if (movimiento.tipo != 'gasto') continue;
      if (!_esDelMes(movimiento.fecha, referencia)) continue;
      acumulador[movimiento.categoria] =
          (acumulador[movimiento.categoria] ?? 0) + movimiento.monto;
    }

    final total = acumulador.values.fold<double>(0, (acc, v) => acc + v);
    final lista = acumulador.entries.map((e) {
      final porcentaje =
          total > 0 ? (e.value / total) * 100 : 0.0;
      return GastoCategoria(
        categoria: e.key,
        total: e.value,
        porcentaje: porcentaje,
      );
    }).toList();
    lista.sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }

  /// Evolución del patrimonio en los últimos N meses, aproximada con el
  /// balance acumulado de movimientos tomando como ancla el patrimonio
  /// actual: para cada mes se descuenta el flujo neto ocurrido después de
  /// ese mes. La serie termina en el patrimonio actual.
  static List<PuntoEvolucion> evolucionPatrimonio(
    List<Asset> activos,
    List<Transaction> movimientos, {
    int meses = mesesEvolucion,
    DateTime? fechaReferencia,
  }) {
    final referencia = fechaReferencia ?? DateTime.now();
    final patrimonioActual =
        activos.fold<double>(0, (acc, a) => acc + a.montoDisponible);

    final flujoNeto = (Transaction m) =>
        m.tipo == 'ingreso' ? m.monto : -m.monto;

    final puntos = <PuntoEvolucion>[];
    for (var i = meses - 1; i >= 0; i--) {
      final mes = DateTime(
        referencia.year,
        referencia.month - i,
        1,
      );
      final inicioSiguiente = DateTime(
        referencia.year,
        referencia.month - i + 1,
        1,
      );
      var flujoPoster = 0.0;
      for (final m in movimientos) {
        if (!m.fecha.isBefore(inicioSiguiente)) {
          flujoPoster += flujoNeto(m);
        }
      }
      puntos.add(PuntoEvolucion(
        fecha: mes,
        valor: patrimonioActual - flujoPoster,
      ));
    }
    return puntos;
  }

  /// Progreso general de metas: porcentaje promedio de cumplimiento de las
  /// metas con objetivo definido. Devuelve `null` si no hay ninguna.
  static ProgresoMetas? progresoPromedioMetas(
    List<FinancialGoal> metas,
  ) {
    final conObjetivo = metas
        .where((m) => m.montoObjetivo != null && m.montoObjetivo! > 0)
        .toList();
    if (conObjetivo.isEmpty) return null;

    double acumulado = 0;
    for (final meta in conObjetivo) {
      final porcentaje = (meta.montoAhorrado / meta.montoObjetivo!)
          .clamp(0.0, 1.0);
      acumulado += porcentaje;
    }
    final promedio = (acumulado / conObjetivo.length) * 100;
    return ProgresoMetas(
      totalMetas: metas.length,
      conObjetivo: conObjetivo.length,
      promedio: promedio,
    );
  }

  /// Total de deudas pendientes (suma de `montoPendiente` de las activas).
  static double totalDeudasPendientes(List<Debt> deudas) {
    return deudas
        .where((deuda) => deuda.montoPendiente > 0)
        .fold<double>(0, (acc, deuda) => acc + deuda.montoPendiente);
  }
}