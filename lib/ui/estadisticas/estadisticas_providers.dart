import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/asset.dart';
import '../../data/models/debt.dart';
import '../../data/models/financial_goal.dart';
import '../../data/models/transaction.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/activos/activos_logic.dart';
import '../../logic/asignaciones/asignacion_logic.dart';
import '../../logic/estadisticas/estadisticas_logic.dart';
import '../../logic/movimientos/movimientos_logic.dart';
import '../asignaciones/asignacion_providers.dart';
import '../deudas/deudas_providers.dart';
import '../metas/metas_providers.dart';
import '../movimientos/movimientos_providers.dart';

/// Datos agregados de la pantalla Estadísticas.
///
/// Observa (ref.watch) los mismos stream providers que consume el resto de
/// la app (poll de 500 ms): cualquier cambio en activos, movimientos, metas,
/// deudas o gastos diarios invalida y recalcula este provider
/// automáticamente. Antes usaba ref.read sobre los repositorios, lo que
/// dejaba el snapshot congelado hasta reiniciar la app.
final estadisticasDatosProvider = FutureProvider<EstadisticasDatos>((ref) async {
  final activos =
      ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
  final movimientos = ref
          .watch(movimientosStreamProvider)
          .asData?.value ??
      const <Transaction>[];
  final metas =
      ref.watch(metasStreamProvider).asData?.value ?? const <FinancialGoal>[];
  final deudas =
      ref.watch(deudasStreamProvider).asData?.value ?? const <Debt>[];

  final hoy = DateTime.now();

  final movimientosMes = movimientos
      .where((m) =>
          m.fecha.year == hoy.year && m.fecha.month == hoy.month)
      .toList();

  // La moneda de cada movimiento es la del activo al que pertenece; los que no
  // tienen activo resoluble quedan en su propio grupo ("sin moneda").
  final monedaDe = <int?, String>{
    for (final activo in activos) activo.id: activo.moneda,
  };
  final ingresosMesPorMoneda =
      MovimientosLogic.totalIngresos(movimientosMes, monedaDe);
  final gastosMesPorMoneda =
      MovimientosLogic.totalGastos(movimientosMes, monedaDe);

  final ingresosMes = ingresosMesPorMoneda.values
      .fold<double>(0, (acc, valor) => acc + valor);
  final gastosMes =
      gastosMesPorMoneda.values.fold<double>(0, (acc, valor) => acc + valor);

  // AFCA: el avance y el reparto salen de los planes vigentes (no archivados),
  // reusando el resumen que ya arma el módulo de asignación.
  final resumenesPlanes = ref.watch(resumenesPlanProvider);
  final planesAfca = resumenesPlanes
      .where((resumen) => !resumen.plan.archivado)
      .toList();

  return EstadisticasDatos(
    patrimonioTotal: ActivosLogic.patrimonioTotalPorMoneda(activos),
    balanceMes:
        MovimientosLogic.balanceNeto(ingresosMesPorMoneda, gastosMesPorMoneda),
    ingresosMes: ingresosMes,
    gastosMes: gastosMes,
    gastosPorCategoria:
        EstadisticasLogic.distribucionGastosPorCategoria(movimientos),
    evolucionPatrimonio: EstadisticasLogic.evolucionPatrimonio(
      activos,
      movimientos,
    ),
    progresoMetas: EstadisticasLogic.progresoPromedioMetas(metas),
    totalDeudasPendientes: EstadisticasLogic.totalDeudasPendientes(deudas),
    // Carga de deuda: se mide con las CUOTAS mensuales activas (no con el
    // total pendiente), igual que en el módulo de Deudas (umbral 40%).
    totalCuotasMensuales: deudas
        .where((deuda) => deuda.montoPendiente > 0)
        .fold<double>(0, (acc, deuda) => acc + (deuda.valorCuota ?? 0)),
    planesAfca: planesAfca,
    repartoAfca: AsignacionLogic.repartoPorCategoria(resumenesPlanes),
    gastoSinPresupuestarMes: AsignacionLogic.gastadoNoPresupuestadoDelMes(
      movimientos,
      referencia: hoy,
    ),
  );
});