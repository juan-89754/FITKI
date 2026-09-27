import '../../data/models/gasto_fijo.dart';
import '../../data/models/pago_gasto_fijo.dart';
import '../../data/models/presupuesto_activo.dart';
import '../../data/models/transaction.dart';

/// El resultado de comparar el límite de un activo contra lo que realmente
/// salió de él durante el mes.
class ResumenPresupuesto {
  final PresupuestoActivo presupuesto;
  final double gastado;
  final List<GastoPorCategoria> porCategoria;

  const ResumenPresupuesto({
    required this.presupuesto,
    required this.gastado,
    required this.porCategoria,
  });

  double get limite => presupuesto.montoLimite;

  /// Lo que queda del límite. En 0 cuando ya se pasó, nunca negativo: el
  /// excedente se lee en [excedido].
  double get restante {
    final diff = limite - gastado;
    return diff > 0 ? diff : 0;
  }

  /// Cuánto se pasó del límite (0 si no se pasó).
  double get excedido {
    final diff = gastado - limite;
    return diff > 0 ? diff : 0;
  }

  double get porcentaje {
    if (limite <= 0) return gastado > 0 ? 100 : 0;
    return (gastado / limite) * 100;
  }

  bool get superado => gastado > limite;
}

/// Un renglón del desglose por categoría. Es de solo lectura: refleja los
/// movimientos reales del activo, no algo que el usuario declare.
class GastoPorCategoria {
  final String categoria;
  final double monto;
  final double porcentaje;

  const GastoPorCategoria({
    required this.categoria,
    required this.monto,
    required this.porcentaje,
  });
}

/// Un pago pendiente del mes junto con su plantilla, listo para pintarse en
/// la lista de "por pagar".
class PendientePago {
  final PagoGastoFijo pago;
  final GastoFijo plantilla;
  final DateTime fechaPago;
  final double montoSugerido;

  const PendientePago({
    required this.pago,
    required this.plantilla,
    required this.fechaPago,
    required this.montoSugerido,
  });

  /// true si la plantilla aún no tiene activo (se borró la cuenta que la
  /// respaldaba): hay que elegir uno antes de poder confirmar el pago.
  bool get requiereActivo => plantilla.activoId == null;
}

/// Lógica de gastos: estimados, generación de pagos del mes y comparación
/// del presupuesto.
///
/// Es un módulo puro: recibe datos y devuelve resultados, sin depender de
/// widgets ni de providers. Toda la aritmética de la app vive aquí para que
/// las pantallas solo pinten lo que este código calcula.
class GastosLogic {
  static const String tipoGasto = Transaction.tipoGasto;

  /// Promedio de los últimos pagos confirmados de un gasto variable, para
  /// precargar un monto que se va afinando con el uso. Devuelve null si
  /// todavía no hay historial, en cuyo caso la pantalla usa el estimado
  /// declarado en la plantilla.
  static double? estimarMontoPagado(
    List<PagoGastoFijo> pagos, {
    int muestras = 3,
  }) {
    final pagados = pagos
        .where((p) => p.montoPagado != null)
        .take(muestras)
        .toList();
    if (pagados.isEmpty) return null;
    final suma = pagados.fold<double>(
      0,
      (acc, p) => acc + (p.montoPagado ?? 0),
    );
    return suma / pagados.length;
  }

  /// Qué pagos hay que crear para el mes/año indicados.
  ///
  /// Devuelve solo los que faltan: una plantilla que ya tiene pago de ese mes
  /// no se vuelve a incluir, así que la generación es idempotente y se puede
  /// llamar cada vez que se abre la app sin miedo a duplicar.
  static List<PagoGastoFijo> pagosPendientesDeGenerar({
    required List<GastoFijo> plantillas,
    required List<PagoGastoFijo> yaExistentes,
    required int mes,
    required int anio,
    required DateTime ahora,
  }) {
    final existentes = yaExistentes
        .where((p) => p.mes == mes && p.anio == anio)
        .map((p) => p.gastoFijoId)
        .toSet();

    final nuevos = <PagoGastoFijo>[];
    for (final plantilla in plantillas) {
      final plantillaId = plantilla.id;
      if (plantillaId == null) continue;
      if (!plantilla.aplicaEn(mes, anio)) continue;
      if (existentes.contains(plantillaId)) continue;
      nuevos.add(
        PagoGastoFijo(
          gastoFijoId: plantillaId,
          mes: mes,
          anio: anio,
          montoEstimado: plantilla.montoEstimado,
          fechaCreacion: ahora,
        ),
      );
    }
    return nuevos;
  }

  /// Los pagos del mes que aún no se pagaron, con la fecha en que tocaba y el
  /// monto a precargar. Los que ya vencieron se ordenan primero.
  ///
  /// [pagos] son los del mes que se está mostrando; [historial] son TODOS los
  /// pagos de todos los meses, y es lo que permite promediar un gasto variable
  /// con lo que realmente se pagó antes. Si se pasara solo el mes, el promedio
  /// nunca tendría con qué calcularse.
  static List<PendientePago> pendientesDelMes({
    required List<PagoGastoFijo> pagos,
    required List<PagoGastoFijo> historial,
    required Map<int, GastoFijo> plantillasPorId,
    required DateTime hoy,
  }) {
    final pendientes = <PendientePago>[];
    for (final pago in pagos) {
      if (pago.pagado) continue;
      final plantilla = plantillasPorId[pago.gastoFijoId];
      if (plantilla == null) continue;
      final montoSugerido = plantilla.montoVariable
          ? estimarMontoPagado(
              _pagosPreviosDe(pago, historial),
            ) ??
              pago.montoEstimado
          : pago.montoEstimado;
      pendientes.add(
        PendientePago(
          pago: pago,
          plantilla: plantilla,
          fechaPago: plantilla.fechaDePagoEn(pago.mes, pago.anio),
          montoSugerido: montoSugerido,
        ),
      );
    }
    pendientes.sort((a, b) => a.fechaPago.compareTo(b.fechaPago));
    return pendientes;
  }

  /// Historial del mismo gasto fijo en meses anteriores al del pago dado.
  static List<PagoGastoFijo> _pagosPreviosDe(
    PagoGastoFijo pago,
    List<PagoGastoFijo> todos,
  ) {
    final delMismo = todos.where(
      (p) =>
          p.gastoFijoId == pago.gastoFijoId &&
          (p.anio < pago.anio || (p.anio == pago.anio && p.mes < pago.mes)),
    );
    final ordenados = delMismo.toList()
      ..sort((a, b) {
        final porAnio = b.anio.compareTo(a.anio);
        if (porAnio != 0) return porAnio;
        return b.mes.compareTo(a.mes);
      });
    return ordenados;
  }

  /// Total estimado de los pagos pendientes de un mes: lo que todavía va a
  /// salir de los activos aunque no se haya pagado.
  static double totalPendiente(List<PagoGastoFijo> pagos) {
    return pagos
        .where((p) => !p.pagado)
        .fold<double>(0, (acc, p) => acc + p.montoEstimado);
  }

  /// Suma de lo efectivamente pagado en un mes, por activo. Devuelve la lista
  /// de pagos pagados para poder mostrar, de paso, cuánto se desvió cada uno
  /// de su estimado.
  static double totalPagadoDelMes(List<PagoGastoFijo> pagos) {
    return pagos
        .where((p) => p.pagado)
        .fold<double>(0, (acc, p) => acc + (p.montoPagado ?? 0));
  }

  /// Compara el límite de un presupuesto contra los movimientos de gasto que
  /// salieron de ese activo en el mes.
  static ResumenPresupuesto compararPresupuesto({
    required PresupuestoActivo presupuesto,
    required List<Transaction> movimientos,
  }) {
    final inicio = DateTime(presupuesto.anio, presupuesto.mes, 1);
    final fin = DateTime(presupuesto.anio, presupuesto.mes + 1, 0);

    final gastosDelActivo = movimientos.where(
      (m) =>
          m.tipo == tipoGasto &&
          m.activoId == presupuesto.activoId &&
          !m.fecha.isBefore(inicio) &&
          !m.fecha.isAfter(fin),
    );

    final gastado = gastosDelActivo.fold<double>(
      0,
      (acc, m) => acc + m.monto,
    );

    return ResumenPresupuesto(
      presupuesto: presupuesto,
      gastado: gastado,
      porCategoria: desglosePorCategoria(gastosDelActivo.toList()),
    );
  }

  /// Agrupa los movimientos por categoría y ordena de mayor a menor. Es una
  /// lectura de lo que ya pasó, no un plan: por eso no necesita compararse con
  /// ningún estimado.
  static List<GastoPorCategoria> desglosePorCategoria(
    List<Transaction> movimientos,
  ) {
    final porCategoria = <String, double>{};
    for (final movimiento in movimientos) {
      if (movimiento.tipo != tipoGasto) continue;
      porCategoria[movimiento.categoria] =
          (porCategoria[movimiento.categoria] ?? 0) + movimiento.monto;
    }
    final total = porCategoria.values.fold<double>(0, (acc, v) => acc + v);
    final renglones = porCategoria.entries.map((e) {
      final porcentaje = total <= 0 ? 0.0 : (e.value / total) * 100;
      return GastoPorCategoria(
        categoria: e.key,
        monto: e.value,
        porcentaje: porcentaje,
      );
    }).toList();
    renglones.sort((a, b) => b.monto.compareTo(a.monto));
    return renglones;
  }

  /// Cuánto se ha gastado del mes en cada activo, para que la lista de
  /// presupuestos de la app muestre de un vistazo cuál se está yendo más.
  static Map<int, double> gastadoPorActivo({
    required List<Transaction> movimientos,
    required int mes,
    required int anio,
  }) {
    final inicio = DateTime(anio, mes, 1);
    final fin = DateTime(anio, mes + 1, 0);
    final resultado = <int, double>{};
    for (final movimiento in movimientos) {
      if (movimiento.tipo != tipoGasto) continue;
      if (movimiento.fecha.isBefore(inicio) || movimiento.fecha.isAfter(fin)) {
        continue;
      }
      final activoId = movimiento.activoId;
      if (activoId == null) continue;
      resultado[activoId] = (resultado[activoId] ?? 0) + movimiento.monto;
    }
    return resultado;
  }
}
