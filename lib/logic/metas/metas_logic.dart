import '../../data/models/financial_goal.dart';

class MetaCalculo {
  final FinancialGoal meta;

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
    required this.montoFaltante,
    required this.porcentajeProgreso,
    required this.semanasRestantes,
    required this.mesesRestantes,
    required this.ahorroSemanal,
    required this.ahorroMensual,
  });
}

class MetasLogic {
  static MetaCalculo calcular(FinancialGoal meta) {
    final objetivo = meta.montoObjetivo;

    final montoFaltante = objetivo != null
        ? (objetivo - meta.montoAhorrado).clamp(0.0, double.infinity)
        : null;

    final porcentaje = (objetivo != null && objetivo > 0)
        ? (meta.montoAhorrado / objetivo).clamp(0.0, 1.0) * 100
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