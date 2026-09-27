import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/debt.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/carga_deuda.dart';
import '../../logic/deudas/deudas_logic.dart';

final deudasStreamProvider = StreamProvider<List<Debt>>((ref) async* {
  final repo = ref.watch(deudaRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (d) => d.toMap());
});

final deudasActivasProvider = Provider<List<Debt>>((ref) {
  final deudas = ref.watch(deudasStreamProvider).asData?.value ?? const [];
  return deudas.where((deuda) => deuda.montoPendiente > 0).toList();
});

final deudasSaldadasProvider = Provider<List<Debt>>((ref) {
  final deudas = ref.watch(deudasStreamProvider).asData?.value ?? const [];
  return deudas.where((deuda) => deuda.montoPendiente <= 0).toList();
});

/// Total pendiente de todas las deudas activas.
final totalDeudaPendienteProvider = Provider<double>((ref) {
  final deudas = ref.watch(deudasActivasProvider);
  return deudas.fold<double>(0, (acc, deuda) => acc + deuda.montoPendiente);
});

/// Progreso global de pago de todas las deudas (fracción 0-1).
final progresoDeudaGlobalProvider = Provider<double>((ref) {
  final deudas = ref.watch(deudasStreamProvider).asData?.value ?? const [];
  final inicial = deudas.fold<double>(
    0,
    (acc, deuda) => acc + DeudasLogic.montoInicialOf(deuda),
  );
  if (inicial <= 0) return 0;
  final pagado = deudas.fold<double>(
    0,
    (acc, deuda) => acc + DeudasLogic.montoPagado(deuda),
  );
  return (pagado / inicial).clamp(0.0, 1.0);
});

final cargaDeudaProvider = FutureProvider<CargaDeuda>((ref) async {
  final deudas = await ref.watch(deudasStreamProvider.future);
  final cuotaTotal = deudas
      .where((deuda) => deuda.montoPendiente > 0)
      .fold<double>(0, (acc, deuda) => acc + (deuda.valorCuota ?? 0));

  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, 1);
  final movimientos = await ref
      .read(movimientoRepositoryProvider)
      .getByRangoFechas(inicio, hoy, tipo: 'ingreso');
  final ingresos =
      movimientos.fold<double>(0, (acc, m) => acc + m.monto);

  final umbral = await ref.watch(umbralCargaDeudaProvider.future);
  return calcularCargaDeuda(cuotaTotal, ingresos, umbral: umbral);
});