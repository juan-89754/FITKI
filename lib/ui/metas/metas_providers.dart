import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/financial_goal.dart';
import '../../data/providers/shared_providers.dart';

final metasStreamProvider = StreamProvider<List<FinancialGoal>>((ref) async* {
  final repo = ref.watch(metaRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (g) => g.toMap());
});