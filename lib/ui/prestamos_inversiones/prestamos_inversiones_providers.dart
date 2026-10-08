import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/loan.dart';
import '../../data/models/investment.dart';
import '../../data/models/inversion_movimiento.dart';
import '../../data/providers/shared_providers.dart';

final prestamosStreamProvider = StreamProvider<List<Loan>>((ref) async* {
  final repo = ref.watch(prestamoRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (l) => l.toMap());
});

final inversionesStreamProvider = StreamProvider<List<Investment>>((ref) async* {
  final repo = ref.watch(inversionRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (i) => i.toMap());
});

/// Historial (aportes, retiros, ganancias y pérdidas) de una inversión.
final movimientosDeInversionProvider =
    StreamProvider.family<List<InversionMovimiento>, int>((ref, inversionId) async* {
  final repo = ref.watch(inversionRepositoryProvider);
  yield* streamDatosFiltrado(
    () => repo.getMovimientosDe(inversionId),
    (m) => m.toMap(),
  );
});