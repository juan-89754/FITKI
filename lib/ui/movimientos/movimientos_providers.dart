import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction.dart';
import '../../data/providers/shared_providers.dart';

final movimientosStreamProvider = StreamProvider<List<Transaction>>((ref) async* {
  final repo = ref.watch(movimientoRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (m) => m.toMap());
});