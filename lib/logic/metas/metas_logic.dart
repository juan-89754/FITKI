import '../../data/models/abono_meta.dart';
import '../../data/models/financial_goal.dart';

class MetaCalculo {
  final FinancialGoal meta;

  /// Dinero actualmente apartado en la meta (Σ aportes − Σ retiros).
  final double saldo;

  /// Cuánto falta ahorrar en total. `null` si la meta no tiene objetivo fijo.
  final double? montoFaltante;

  /// Progreso acumulado (0-100). Sin objetivo fijo siempre es 0.
  final double porcentajeProgreso;

  /// Períodos restantes hasta la fecha estimada. `null` si no hay fecha
  /// o si la fecha ya pasó (quedan 0 períodos).
  final int? semanasRestantes;
  final int? mesesRestantes;

  /// Cuánto ahorrar por período. `null` si no hay objetivo, no hay fecha,
  /// faltan períodos o ya está cumplida.
  final double? ahorroSemanal;
  final double? ahorroMensual;

  bool get cumpleObjetivo => meta.montoObjetivo != null && montoFaltante == 0;

  const MetaCalculo({
    required this.meta,
    required this.saldo,
    required this.montoFaltante,
    required this.porcentajeProgreso,
    required this.semanasRestantes,
    required this.mesesRestantes,
    required this.ahorroSemanal,
    required this.ahorroMensual,
  });
}

class MetasLogic {
  /// Saldo de una meta: la suma con signo de sus registros (Σ aportes −
  /// Σ retiros).
  ///
  /// Es la única forma de obtener el saldo. El valor guardado en
  /// `FinancialGoal.montoAhorrado` es una copia que el repositorio refresca en
  /// la misma transacción que escribe cada registro, y se usa solo cuando la
  /// pantalla aún no tiene el historial a la vista.
  static double saldoDeMeta(List<AbonoMeta> registros) {
    double saldo = 0;
    for (final registro in registros) {
      saldo += registro.montoConSigno;
    }
    return saldo;
  }

  /// Dinero de una meta que está reservado en [activoId]: sirve para validar un
  /// retiro sin consultar la base.
  static double reservadoEnActivo(
    List<AbonoMeta> registros,
    int? activoId,
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

  /// Calcula el avance de la meta.
  ///
  /// Si se pasan los registros, el saldo sale de ellos ([saldoDeMeta]); si no,
  /// se usa el acumulado guardado. El resto de los cálculos depende solo del
  /// saldo y del objetivo, así que son idénticos en ambos caminos.
  static MetaCalculo calcular(
    FinancialGoal meta, {
    List<AbonoMeta>? registros,
  }) {
    final objetivo = meta.montoObjetivo;
    final saldo = registros == null ? meta.montoAhorrado : saldoDeMeta(registros);

    final montoFaltante = objetivo != null
        ? (objetivo - saldo).clamp(0.0, double.infinity)
        : null;

    final porcentaje = (objetivo != null && objetivo > 0)
        ? (saldo / objetivo).clamp(0.0, 1.0) * 100
        : 0.0;

    final semanas = _semanasRestantes(meta.fechaEstimada);
    final meses = _mesesRestantes(meta.fechaEstimada);

    final ahorroSemanal = (montoFaltante != null && (semanas ?? 0) > 0)
        ? montoFaltante / semanas!
        : null;
    final ahorroMensual = (montoFaltante != null && (meses ?? 0) > 0)
        ? montoFaltante / meses!
        : null;

    return MetaCalculo(
      meta: meta,
      saldo: saldo,
      montoFaltante: montoFaltante,
      porcentajeProgreso: porcentaje,
      semanasRestantes: semanas,
      mesesRestantes: meses,
      ahorroSemanal: ahorroSemanal,
      ahorroMensual: ahorroMensual,
    );
  }

  static int? _semanasRestantes(DateTime? fechaEstimada) {
    if (fechaEstimada == null) return null;
    final dias = fechaEstimada.difference(DateTime.now()).inDays;
    if (dias < 0) return 0;
    return (dias / 7).ceil();
  }

  static int? _mesesRestantes(DateTime? fechaEstimada) {
    if (fechaEstimada == null) return null;
    final hoy = DateTime.now();
    var meses = (fechaEstimada.year - hoy.year) * 12 +
        (fechaEstimada.month - hoy.month);
    if (fechaEstimada.day < hoy.day) meses -= 1;
    return meses < 0 ? 0 : meses;
  }
}