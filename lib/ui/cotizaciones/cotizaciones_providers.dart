import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/shared_providers.dart';
import '../../data/repositories/proyecto_repository.dart';
import '../../data/repositories/cotizacion_repository.dart';
import '../../data/repositories/item_cotizacion_repository.dart';
import '../../data/models/quote_project.dart';
import '../../data/models/quote.dart';
import '../../data/models/quote_item.dart';

final proyectoRepositoryProvider = Provider<ProyectoRepository>((ref) {
  return ProyectoRepository();
});

final cotizacionRepositoryProvider = Provider<CotizacionRepository>((ref) {
  return CotizacionRepository();
});

final itemCotizacionRepositoryProvider = Provider<ItemCotizacionRepository>(
  (ref) => ItemCotizacionRepository(),
);

final proyectosStreamProvider = StreamProvider<List<QuoteProject>>((ref) async* {
  final repo = ref.watch(proyectoRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (p) => p.toMap());
});

final cotizacionesStreamProvider = StreamProvider<List<Quote>>((ref) async* {
  final repo = ref.watch(cotizacionRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (c) => c.toMap());
});

final itemsStreamProvider = StreamProvider<List<QuoteItem>>((ref) async* {
  final repo = ref.watch(itemCotizacionRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (i) => i.toMap());
});