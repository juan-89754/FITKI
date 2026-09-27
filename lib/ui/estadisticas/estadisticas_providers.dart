import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/asset.dart';
import '../../data/models/debt.dart';
import '../../data/models/financial_goal.dart';
import '../../data/models/transaction.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/estadisticas/estadisticas_logic.dart';
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
  final ingresosMes = movimientosMes
      .where((m) => m.tipo == 'ingreso')
      .fold<double>(0, (acc, m) => acc + m.monto);
  final gastosMes = movimientosMes
      .where((m) => m.tipo == 'gasto')
      .fold<double>(0, (acc, m) => acc + m.monto);

  return EstadisticasDatos(
    patrimonioTotal:
        activos.fold<double>(0, (acc, a) => acc + a.montoDisponible),
    balanceMes: ingresosMes - gastosMes,
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
  );
});