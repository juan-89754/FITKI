import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/abono_meta.dart';
import '../../data/models/financial_goal.dart';
import '../../data/providers/shared_providers.dart';

final metasStreamProvider = StreamProvider<List<FinancialGoal>>((ref) async* {
  final repo = ref.watch(metaRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (g) => g.toMap());
});

/// Aportes y retiros de una meta, del más reciente al más antiguo. Es `family`
/// porque cada meta tiene su propio historial y la pantalla de detalle solo
/// necesita el suyo; el poll es el mismo de 500 ms, así que refleja los cambios
/// sin que nadie tenga que invalidarlo a mano.
final registrosDeMetaProvider =
    StreamProvider.family<List<AbonoMeta>, int>((ref, metaId) async* {
  final repo = ref.watch(metaRepositoryProvider);
  yield* streamDatosFiltrado(
    () => repo.getRegistrosDe(metaId),
    (a) => a.toMap(),
  );
});

/// Aportes y retiros de **todas** las metas.
///
/// El Saldo Disponible de un activo necesita las reservas de todas las metas, no
/// solo de una: el dinero reservado sale de una cuenta, así que se suma por
/// cuenta, y esa suma solo existe mirando todos los registros a la vez. Por eso
/// este provider no es `family`.
final registrosDeMetasProvider = StreamProvider<List<AbonoMeta>>((ref) async* {
  final repo = ref.watch(metaRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAllRegistros, (a) => a.toMap());
});