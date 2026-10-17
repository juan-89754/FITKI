import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/asset.dart';
import '../../data/models/detalle_asignacion.dart';
import '../../data/models/plan_asignacion.dart';
import '../../data/models/transaction.dart';
import '../../data/providers/shared_providers.dart';
import '../../data/repositories/detalle_asignacion_repository.dart';
import '../../data/repositories/plan_asignacion_repository.dart';
import '../../logic/asignaciones/asignacion_logic.dart';
import '../movimientos/movimientos_providers.dart';

final planAsignacionRepositoryProvider = Provider<PlanAsignacionRepository>((
  ref,
) {
  return PlanAsignacionRepository();
});

final detalleAsignacionRepositoryProvider =
    Provider<DetalleAsignacionRepository>((ref) {
      return DetalleAsignacionRepository();
    });

/// Todos los planes. Los consume el módulo AFCA para pintar el dashboard y
/// para resolver los vínculos automáticos de gastos.
final planesAsignacionStreamProvider =
    StreamProvider<List<PlanAsignacion>>((ref) async* {
      final repo = ref.watch(planAsignacionRepositoryProvider);
      yield* streamDatosFiltrado(repo.getAll, (p) => p.toMap());
    });

/// Todos los bolsillos de todos los planes. Se cargan completos (como el resto
/// de la app) para que las sumas derivadas no dependan de consultas por plan.
final detallesAsignacionStreamProvider =
    StreamProvider<List<DetalleAsignacion>>((ref) async* {
      final repo = ref.watch(detalleAsignacionRepositoryProvider);
      yield* streamDatosFiltrado(repo.getAll, (d) => d.toMap());
    });

/// Resúmenes de todos los planes, con lo gastado ya derivado del historial de
/// movimientos. Ordenados por los activos y proyectados al final.
final resumenesPlanProvider = Provider<List<ResumenPlan>>((ref) {
  final planes =
      ref.watch(planesAsignacionStreamProvider).asData?.value ??
      const <PlanAsignacion>[];
  final detalles =
      ref.watch(detallesAsignacionStreamProvider).asData?.value ??
      const <DetalleAsignacion>[];
  final movimientos =
      ref.watch(movimientosStreamProvider).asData?.value ?? const [];

  final detallesPorPlan = <int, List<DetalleAsignacion>>{};
  for (final detalle in detalles) {
    final planId = detalle.planId;
    if (planId == null) continue;
    detallesPorPlan.putIfAbsent(planId, () => []).add(detalle);
  }

  return planes
      .map(
        (plan) => AsignacionLogic.resumirPlan(
          plan: plan,
          detalles: detallesPorPlan[plan.id] ?? const <DetalleAsignacion>[],
          movimientos: movimientos,
        ),
      )
      .toList();
});

/// Saldos de un activo separando lo físico de lo comprometido en sus planes
/// con fondos reales.
///
/// Es el corazón de la idea AFCA: el saldo de la cuenta es solo un número; lo
/// que importa es cuánto de ese dinero ya tiene destino. Los planes proyectados
/// no comprometen nada porque su dinero todavía no existe.
final saldosActivoProvider = Provider.family<SaldosActivo, int>((
  ref,
  activoId,
) {
  final activos =
      ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
  final planes =
      ref.watch(planesAsignacionStreamProvider).asData?.value ??
      const <PlanAsignacion>[];
  final detalles =
      ref.watch(detallesAsignacionStreamProvider).asData?.value ??
      const <DetalleAsignacion>[];

  final saldoReal = activos
      .where((a) => a.id == activoId)
      .fold<double>(0, (acc, a) => acc + a.montoDisponible);

  return AsignacionLogic.saldosDeActivo(
    saldoReal: saldoReal,
    activoId: activoId,
    planes: planes,
    detalles: detalles,
  );
});

/// Resumen de un plan concreto, con su gasto derivado del historial.
final resumenPlanProvider = Provider.family<ResumenPlan?, int>((ref, planId) {
  final planes =
      ref.watch(planesAsignacionStreamProvider).asData?.value ??
      const <PlanAsignacion>[];
  PlanAsignacion? plan;
  for (final candidato in planes) {
    if (candidato.id == planId) {
      plan = candidato;
      break;
    }
  }
  if (plan == null) return null;

  final detalles =
      ref.watch(detallesAsignacionStreamProvider).asData?.value ??
      const <DetalleAsignacion>[];
  final movimientos =
      ref.watch(movimientosStreamProvider).asData?.value ?? const [];

  return AsignacionLogic.resumirPlan(
    plan: plan,
    detalles: detalles.where((d) => d.planId == planId).toList(),
    movimientos: movimientos,
  );
});

/// Gastos imputados a un bolsillo, más recientes primero.
///
/// Es el drill-down que respalda el "gastado" del bolsillo: permite ver en qué
/// se fue el dinero asignado, no solo cuánto queda.
final movimientosDeBolsilloProvider =
    Provider.family<List<Transaction>, int>((ref, planDetalleId) {
      final movimientos =
          ref.watch(movimientosStreamProvider).asData?.value ??
          const <Transaction>[];
      return AsignacionLogic.movimientosDeDetalle(planDetalleId, movimientos);
    });

/// Nombre de cada activo, para mostrar el dueño de un plan sin volver a mirar
/// la base.
final nombreActivoProvider = Provider.family<String?, int>((ref, activoId) {
  final activos =
      ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
  for (final activo in activos) {
    if (activo.id == activoId) return activo.nombre;
  }
  return null;
});

/// Nombre del plan al que pertenece un bolsillo, para etiquetar el destino de
/// un movimiento en su detalle.
///
/// Devuelve el nombre del plan y no una etiqueta armada: la UI resuelve la
/// categoría con sus propios íconos y acentos, y acá solo se necesita saber a
/// qué plan se imputó.
final nombrePlanDeBolsilloProvider = Provider.family<String?, int>((
  ref,
  planDetalleId,
) {
  final detalles =
      ref.watch(detallesAsignacionStreamProvider).asData?.value ??
      const <DetalleAsignacion>[];
  int? planId;
  for (final detalle in detalles) {
    if (detalle.id == planDetalleId) {
      planId = detalle.planId;
      break;
    }
  }
  if (planId == null) return null;

  final planes =
      ref.watch(planesAsignacionStreamProvider).asData?.value ??
      const <PlanAsignacion>[];
  for (final plan in planes) {
    if (plan.id == planId) return plan.nombre;
  }
  return null;
});
