import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/activos/activos_logic.dart';

final patrimonioProvider = Provider<List<PatrimonioPorMoneda>>((ref) {
  final activos = ref.watch(activosStreamProvider).asData?.value ?? [];
  return ActivosLogic.calcularPatrimonioPorMoneda(activos);
});

final patrimonioTotalProvider = Provider<double>((ref) {
  final activos = ref.watch(activosStreamProvider).asData?.value ?? [];
  return ActivosLogic.calcularPatrimonioTotal(activos);
});