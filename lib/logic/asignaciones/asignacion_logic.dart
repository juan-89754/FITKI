import '../../data/models/detalle_asignacion.dart';
import '../../data/models/plan_asignacion.dart';
import '../../data/models/transaction.dart';

/// Resumen de un bolsillo: lo asignado contra lo realmente gastado.
///
/// `gastado` no vive en la base: se deriva de los movimientos vinculados a este
/// detalle, así el plan y la realidad nunca se desincronizan al editar o borrar
/// una transacción.
class ResumenDetalle {
  final DetalleAsignacion detalle;
  final double gastado;

  const ResumenDetalle({required this.detalle, required this.gastado});

  String get categoria => detalle.categoria;

  double get asignado => detalle.montoAsignado;

  /// Lo que queda por gastar. En 0 cuando ya se pasó, nunca negativo.
  double get restante {
    final diff = asignado - gastado;
    return diff > 0 ? diff : 0;
  }

  /// Cuánto se pasó del bolsillo (0 si no se pasó).
  double get excedido {
    final diff = gastado - asignado;
    return diff > 0 ? diff : 0;
  }

  double get porcentaje {
    if (asignado <= 0) return gastado > 0 ? 100 : 0;
    return (gastado / asignado) * 100;
  }

  bool get superado => gastado > asignado;
}

/// Resumen completo de un plan: sus bolsillos y las cuentas del plan.
class ResumenPlan {
  final PlanAsignacion plan;
  final List<ResumenDetalle> detalles;

  const ResumenPlan({required this.plan, required this.detalles});

  double get totalObjetivo => plan.montoTotalObjetivo;

  /// Suma de lo asignado a los bolsillos.
  double get totalAsignado =>
      detalles.fold<double>(0, (acc, d) => acc + d.asignado);

  /// Dinero del plan que todavía no tiene destino. Puede ser negativo si se
  /// asignó de más.
  double get sinAsignar => totalObjetivo - totalAsignado;

  double get gastadoTotal =>
      detalles.fold<double>(0, (acc, d) => acc + d.gastado);

  /// Porcentaje del dinero asignado que ya se gastó en los bolsillos. Es el
  /// avance del plan: 0% sin gastos, 100% a pleno, por encima de 100% excedido.
  double get porcentajeUsado {
    if (totalAsignado <= 0) return 0;
    return (gastadoTotal / totalAsignado) * 100;
  }

  /// El plan está cuadrado cuando no queda dinero sin asignar.
  bool get cuadrado => sinAsignar.abs() < 0.005;
}

/// Reparto del dinero asignado por categoría, sumando los bolsillos de varios
/// planes. Sirve para ver hacia dónde apunta el presupuesto en conjunto.
class RepartoCategoria {
  final String categoria;
  final double asignado;
  final double gastado;

  const RepartoCategoria({
    required this.categoria,
    required this.asignado,
    required this.gastado,
  });

  /// Lo que queda por gastar. En 0 cuando ya se pasó, nunca negativo.
  double get restante {
    final diff = asignado - gastado;
    return diff > 0 ? diff : 0;
  }

  double get porcentajeUsado {
    if (asignado <= 0) return 0;
    return (gastado / asignado) * 100;
  }

  bool get superado => gastado > asignado;
}

/// Saldos de un activo separando el dinero físico de lo ya comprometido.
class SaldosActivo {
  final double saldoReal;
  final double comprometido;

  const SaldosActivo({required this.saldoReal, required this.comprometido});

  /// Lo que sigue disponible para gastar o reasignar: el saldo real menos lo
  /// apartado en planes con fondos. Puede ser negativo (se comprometió más de
  /// lo que hay).
  double get libre => saldoReal - comprometido;
}

/// Lógica del módulo AFCA. Es un módulo puro: recibe datos y devuelve
/// resultados, sin depender de widgets ni de providers.
class AsignacionLogic {
  static const String tipoGasto = Transaction.tipoGasto;

  /// Dinero del plan que aún no se repartió entre bolsillos.
  static double dineroSinAsignar(
    PlanAsignacion plan,
    List<DetalleAsignacion> detalles,
  ) {
    final asignado = detalles.fold<double>(0, (acc, d) => acc + d.montoAsignado);
    return plan.montoTotalObjetivo - asignado;
  }

  /// Gastos vinculados a un bolsillo concreto, sin importar el orden.
  static Iterable<Transaction> _gastosDeDetalle(
    int detalleId,
    List<Transaction> movimientos,
  ) {
    return movimientos.where(
      (m) => m.tipo == tipoGasto && m.planDetalleId == detalleId,
    );
  }

  /// Suma lo gastado imputado a un bolsillo concreto, leyendo el historial.
  static double gastadoDeDetalle(
    DetalleAsignacion detalle,
    List<Transaction> movimientos,
  ) {
    final id = detalle.id;
    if (id == null) return 0;
    var total = 0.0;
    for (final movimiento in _gastosDeDetalle(id, movimientos)) {
      total += movimiento.monto;
    }
    return total;
  }

  /// Movimientos (solo gastos) imputados a un bolsillo, más recientes primero.
  ///
  /// Es el historial que respalda el "gastado" del bolsillo: el drill-down que
  /// permite ver en qué se fue el dinero asignado, no solo cuánto queda.
  static List<Transaction> movimientosDeDetalle(
    int detalleId,
    List<Transaction> movimientos,
  ) {
    final resultado = _gastosDeDetalle(detalleId, movimientos).toList();
    resultado.sort((a, b) => b.fecha.compareTo(a.fecha));
    return resultado;
  }

  /// Arma el resumen de un plan con lo gastado derivado de [movimientos].
  static ResumenPlan resumirPlan({
    required PlanAsignacion plan,
    required List<DetalleAsignacion> detalles,
    required List<Transaction> movimientos,
  }) {
    final resumenes = detalles
        .map(
          (d) => ResumenDetalle(
            detalle: d,
            gastado: gastadoDeDetalle(d, movimientos),
          ),
        )
        .toList();
    return ResumenPlan(plan: plan, detalles: resumenes);
  }

  /// Gastos sin bolsillo asignado, sin importar el período.
  static Iterable<Transaction> _gastosNoPresupuestados(
    List<Transaction> movimientos,
  ) {
    return movimientos.where(
      (m) => m.tipo == tipoGasto && m.planDetalleId == null,
    );
  }

  /// Todo lo gastado sin bolsillo asignado ("gasto no presupuestado").
  static double gastadoNoPresupuestado(List<Transaction> movimientos) {
    var total = 0.0;
    for (final movimiento in _gastosNoPresupuestados(movimientos)) {
      total += movimiento.monto;
    }
    return total;
  }

  /// Gastos del mes de [referencia] sin bolsillo asignado: cuánto del gasto se
  /// escapó del reparto en el período, no en toda la historia.
  static double gastadoNoPresupuestadoDelMes(
    List<Transaction> movimientos, {
    DateTime? referencia,
  }) {
    final ref = referencia ?? DateTime.now();
    var total = 0.0;
    for (final movimiento in _gastosNoPresupuestados(movimientos)) {
      if (movimiento.fecha.year != ref.year ||
          movimiento.fecha.month != ref.month) {
        continue;
      }
      total += movimiento.monto;
    }
    return total;
  }

  /// Reparto por categoría de los bolsillos de [resumenes].
  ///
  /// Con [incluirArchivados] en `false` (por defecto) deja fuera los planes
  /// archivados: un plan cerrado ya no es parte del presupuesto vigente.
  static List<RepartoCategoria> repartoPorCategoria(
    List<ResumenPlan> resumenes, {
    bool incluirArchivados = false,
  }) {
    final asignado = <String, double>{};
    final gastado = <String, double>{};
    for (final resumen in resumenes) {
      if (!incluirArchivados && resumen.plan.archivado) continue;
      for (final detalle in resumen.detalles) {
        asignado[detalle.categoria] =
            (asignado[detalle.categoria] ?? 0) + detalle.asignado;
        gastado[detalle.categoria] =
            (gastado[detalle.categoria] ?? 0) + detalle.gastado;
      }
    }

    final lista = [
      for (final categoria in asignado.keys)
        RepartoCategoria(
          categoria: categoria,
          asignado: asignado[categoria]!,
          gastado: gastado[categoria] ?? 0,
        ),
    ];
    lista.sort((a, b) => b.asignado.compareTo(a.asignado));
    return lista;
  }

  /// Planes que todavía pueden recibir gastos en una cuenta dada.
  ///
  /// Un plan archivado ya cerró y un proyectado no tiene dinero todavía, así
  /// que ninguno de los dos acepta movimientos. Con [activoId] en `null` se
  /// consideran todas las cuentas, para cuando el usuario todavía no eligió.
  static Set<int> _planesElegibles({
    required int? activoId,
    required List<PlanAsignacion> planes,
  }) {
    return {
      for (final plan in planes)
        if (plan.id != null &&
            plan.activo &&
            !plan.esProyectado &&
            (activoId == null || plan.activoId == activoId))
          plan.id!,
    };
  }

  /// Bolsillos a los que un gasto podría imputarse por su cuenta y categoría.
  ///
  /// Es la lista que ofrece el formulario al registrar un gasto: cada uno es un
  /// destino posible, con lo que le queda de su asignación. Los planes
  /// proyectados quedan fuera porque su dinero todavía no existe.
  static List<ResumenDetalle> bolsillosCandidatos({
    required String categoria,
    required int? activoId,
    required List<ResumenPlan> resumenes,
  }) {
    final elegibles = _planesElegibles(
      activoId: activoId,
      planes: [for (final resumen in resumenes) resumen.plan],
    );

    final resultado = <ResumenDetalle>[];
    for (final resumen in resumenes) {
      for (final detalle in resumen.detalles) {
        if (detalle.detalle.planId == null) continue;
        if (!elegibles.contains(detalle.detalle.planId)) continue;
        if (detalle.categoria != categoria) continue;
        resultado.add(detalle);
      }
    }
    return resultado;
  }

  /// Resuelve a qué bolsillo imputar un gasto que no se vinculó a mano.
  ///
  /// Solo considera planes activos, con fondos reales (un plan proyectado no
  /// tiene dinero todavía) y del mismo activo. Si hay exactamente una
  /// coincidencia por categoría, la devuelve; si hay cero o más de una, deja
  /// el gasto sin presupuestar (`null`), para no adivinar.
  static int? resolverVinculoAutomatico({
    required String categoria,
    required int? activoId,
    required List<PlanAsignacion> planes,
    required List<DetalleAsignacion> detalles,
  }) {
    final planesElegibles = _planesElegibles(
      activoId: activoId,
      planes: planes,
    );

    final coincidencias = detalles
        .where(
          (d) =>
              d.id != null &&
              d.planId != null &&
              planesElegibles.contains(d.planId) &&
              d.categoria == categoria,
        )
        .toList();

    if (coincidencias.length == 1) return coincidencias.first.id;
    return null;
  }

  /// Saldo comprometido en los planes de un activo: lo asignado en planes con
  /// fondos reales y aún activos. Los proyectados no comprometen nada.
  static double saldoComprometido({
    required int activoId,
    required List<PlanAsignacion> planes,
    required List<DetalleAsignacion> detalles,
  }) {
    final planesActivos = <int>{
      for (final plan in planes)
        if (plan.id != null &&
            plan.activo &&
            !plan.esProyectado &&
            plan.activoId == activoId)
          plan.id!,
    };
    var total = 0.0;
    for (final detalle in detalles) {
      if (detalle.planId != null && planesActivos.contains(detalle.planId)) {
        total += detalle.montoAsignado;
      }
    }
    return total;
  }

  /// Saldos de un activo separando lo físico de lo comprometido en planes.
  static SaldosActivo saldosDeActivo({
    required double saldoReal,
    required int activoId,
    required List<PlanAsignacion> planes,
    required List<DetalleAsignacion> detalles,
  }) {
    return SaldosActivo(
      saldoReal: saldoReal,
      comprometido: saldoComprometido(
        activoId: activoId,
        planes: planes,
        detalles: detalles,
      ),
    );
  }
}
