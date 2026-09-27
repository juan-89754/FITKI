import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../preferences/app_preferences.dart';
import '../repositories/activo_repository.dart';
import '../repositories/movimiento_repository.dart';
import '../repositories/meta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/prestamo_repository.dart';
import '../repositories/inversion_repository.dart';
import '../repositories/perfil_repository.dart';
import '../models/asset.dart';
import '../models/perfil.dart';
import '../models/categoria_personalizada.dart';
import '../repositories/categoria_personalizada_repository.dart';

/// Poll de 500 ms que solo emite cuando el contenido cambió de verdad.
///
/// Los repositorios construyen listas nuevas en cada consulta aunque nada
/// haya cambiado; sin este filtro cada tick invalida a todos los providers
/// que observan el stream y las pantallas se reconstruyen (parpadeo).
Stream<List<R>> streamDatosFiltrado<R>(
  Future<List<R>> Function() leer,
  Map<String, dynamic> Function(R) aMapa,
) async* {
  var firmaAnterior = '';
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    final datos = await leer();
    final firma = '${datos.length}|${datos.map(aMapa).toList().toString()}';
    if (firma != firmaAnterior) {
      firmaAnterior = firma;
      yield datos;
    }
  }
}

final activoRepositoryProvider = Provider<ActivoRepository>((ref) {
  return ActivoRepository();
});

final activosStreamProvider = StreamProvider<List<Asset>>((ref) async* {
  final repo = ref.watch(activoRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (a) => a.toMap());
});

final movimientoRepositoryProvider = Provider<MovimientoRepository>((ref) {
  return MovimientoRepository();
});

final metaRepositoryProvider = Provider<MetaRepository>((ref) {
  return MetaRepository();
});

final deudaRepositoryProvider = Provider<DeudaRepository>((ref) {
  return DeudaRepository();
});

final prestamoRepositoryProvider = Provider<PrestamoRepository>((ref) {
  return PrestamoRepository();
});

final inversionRepositoryProvider = Provider<InversionRepository>((ref) {
  return InversionRepository();
});

final perfilRepositoryProvider = Provider<PerfilRepository>((ref) {
  return PerfilRepository();
});

final perfilStreamProvider = StreamProvider<Perfil?>((ref) async* {
  final repo = ref.watch(perfilRepositoryProvider);
  String? firmaAnterior;
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    final perfil = await repo.obtenerUno();
    final firma = perfil?.toMap().toString();
    if (firma != firmaAnterior) {
      firmaAnterior = firma;
      yield perfil;
    }
  }
});

/// Umbral de carga de deuda configurado (fracción 0-1, default 0.40). Se
/// invalida desde Configuraciones al cambiar el Slider para que las pantallas
/// que lo comparan (Deudas y Estadísticas) recalculen la alerta.
final umbralCargaDeudaProvider = FutureProvider<double>((ref) async {
  return AppPreferences.getUmbralCargaDeuda();
});

final categoriaPersonalizadaRepositoryProvider =
    Provider<CategoriaPersonalizadaRepository>((ref) {
  return CategoriaPersonalizadaRepository();
});

/// Categorías personalizadas del usuario. Lo consumen los dropdowns de
/// categoría (vía `categoriasDeTipo` de categoria_labels.dart) y la pantalla
/// de administración de categorías.
final categoriasPersonalizadasStreamProvider =
    StreamProvider<List<CategoriaPersonalizada>>((ref) async* {
  final repo = ref.watch(categoriaPersonalizadaRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (c) => c.toMap());
});