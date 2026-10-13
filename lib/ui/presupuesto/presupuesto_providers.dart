import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gasto_fijo.dart';
import '../../data/models/pago_gasto_fijo.dart';
import '../../data/models/presupuesto_categoria.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/gasto_fijo_repository.dart';
import '../../data/repositories/pago_gasto_fijo_repository.dart';
import '../../data/repositories/presupuesto_categoria_repository.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/gastos/gastos_logic.dart';
import '../../logic/gastos/periodo.dart';
import '../movimientos/movimientos_providers.dart';

final gastoFijoRepositoryProvider = Provider<GastoFijoRepository>((ref) {
  return GastoFijoRepository();
});

final pagoGastoFijoRepositoryProvider = Provider<PagoGastoFijoRepository>((
  ref,
) {
  return PagoGastoFijoRepository();
});

final presupuestoCategoriaRepositoryProvider =
    Provider<PresupuestoCategoriaRepository>((ref) {
      return PresupuestoCategoriaRepository();
    });

/// Mes que están viendo las pantallas del módulo. Cambiarlo repinta tanto el
/// presupuesto como los pagos fijos del mes, que es justo lo que faltaba antes
/// (solo se podía ver el mes en curso).
final periodoVisibleProvider = StateProvider<Periodo>(
  (ref) => Periodo.actual(),
);

final gastosFijosStreamProvider = StreamProvider<List<GastoFijo>>((ref) async* {
  final repo = ref.watch(gastoFijoRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (g) => g.toMap());
});

final pagosGastosFijosStreamProvider = StreamProvider<List<PagoGastoFijo>>((
  ref,
) async* {
  final repo = ref.watch(pagoGastoFijoRepositoryProvider);
  yield* streamDatosFiltrado(repo.getAll, (p) => p.toMap());
});

final presupuestosCategoriasStreamProvider =
    StreamProvider<List<PresupuestoCategoria>>((ref) async* {
      final repo = ref.watch(presupuestoCategoriaRepositoryProvider);
      yield* streamDatosFiltrado(repo.getAll, (p) => p.toMap());
    });

/// Pagos del mes visible, generándolos si todavía no existen.
///
/// Es la parte que quita el trabajo manual: al abrir el módulo, cada plantilla
/// vigente que no tenga pago del mes genera el suyo. La generación es
/// idempotente (combinada con el UNIQUE de la tabla), así que repetirla en cada
/// reconstrucción no duplica nada.
final pagosDelMesProvider = FutureProvider<List<PagoGastoFijo>>((ref) async {
  final repoPagos = ref.watch(pagoGastoFijoRepositoryProvider);
  final periodo = ref.watch(periodoVisibleProvider);

  final todos =
      ref.watch(pagosGastosFijosStreamProvider).asData?.value ??
      const <PagoGastoFijo>[];
  final plantillas =
      ref.watch(gastosFijosStreamProvider).asData?.value ??
      const <GastoFijo>[];

  // Mientras las plantillas no hayan cargado no se genera nada: se espera a la
  // siguiente emisión del stream en vez de crear pagos de más.
  if (plantillas.isEmpty && todos.isEmpty) {
    return todos
        .where((p) => p.mes == periodo.mes && p.anio == periodo.anio)
        .toList();
  }

  final nuevos = GastosLogic.pagosPendientesDeGenerar(
    plantillas: plantillas,
    yaExistentes: todos,
    mes: periodo.mes,
    anio: periodo.anio,
    ahora: DateTime.now(),
  );

  var delMes = todos
      .where((p) => p.mes == periodo.mes && p.anio == periodo.anio)
      .toList();
  if (nuevos.isNotEmpty) {
    try {
      await repoPagos.insertVarios(nuevos);
      delMes = [...delMes, ...nuevos];
    } catch (_) {
      // Si el UNIQUE choca es que otro passage ya los creó: se devuelven los
      // que había y el stream traerá los nuevos en el siguiente tick.
    }
  }
  return delMes;
});

/// Los pendientes del mes visible, ordenados por fecha de pago y con el monto
/// ya sugerido (el estimado, o el promedio de los últimos pagos si el precio
/// es variable).
final pendientesDelMesProvider = FutureProvider<List<PendientePago>>((
  ref,
) async {
  final pagos = await ref.watch(pagosDelMesProvider.future);
  // El historial completo es lo que permite promediar los gastos de precio
  // variable con lo que se pagó en meses anteriores.
  final historial =
      ref.watch(pagosGastosFijosStreamProvider).asData?.value ??
      const <PagoGastoFijo>[];
  final plantillas =
      ref.watch(gastosFijosStreamProvider).asData?.value ?? const <GastoFijo>[];
  return GastosLogic.pendientesDelMes(
    pagos: pagos,
    historial: historial,
    plantillasPorId: {
      for (final g in plantillas)
        if (g.id != null) g.id!: g,
    },
    hoy: DateTime.now(),
  );
});

/// Movimientos del mes visible, base de todo el cálculo de lo gastado.
final movimientosDelMesProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final movimientos =
      ref.watch(movimientosStreamProvider).asData?.value ??
      const <Transaction>[];
  final periodo = ref.watch(periodoVisibleProvider);
  final inicio = DateTime(periodo.anio, periodo.mes, 1);
  final fin = DateTime(periodo.anio, periodo.mes + 1, 0);
  return movimientos
      .where((m) => !m.fecha.isBefore(inicio) && !m.fecha.isAfter(fin))
      .toList();
});

/// Resumen de cada presupuesto del mes visible: límite, gastado, restante y
/// porcentaje de uso, ordenado por lo más gastado primero.
final resumenesPresupuestoProvider = FutureProvider<List<ResumenPresupuesto>>((
  ref,
) async {
  final presupuestos =
      ref.watch(presupuestosCategoriasStreamProvider).asData?.value ??
      const <PresupuestoCategoria>[];
  final movimientos = await ref.watch(movimientosDelMesProvider.future);
  final periodo = ref.watch(periodoVisibleProvider);

  final resumenes = presupuestos
      .where((p) => p.mes == periodo.mes && p.anio == periodo.anio)
      .map(
        (p) => GastosLogic.compararPresupuestoCategoria(
          presupuesto: p,
          movimientos: movimientos,
        ),
      )
      .toList();
  resumenes.sort((a, b) => b.gastado.compareTo(a.gastado));
  return resumenes;
});

/// Lo que ya se gastó este mes en cada categoría, para las categorías que
/// todavía no tienen presupuesto creado.
final gastadoPorCategoriaMesProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final movimientos = await ref.watch(movimientosDelMesProvider.future);
  final periodo = ref.watch(periodoVisibleProvider);
  return GastosLogic.gastadoPorCategoria(
    movimientos: movimientos,
    mes: periodo.mes,
    anio: periodo.anio,
  );
});

/// Promedio mensual de los últimos 3 meses de gasto de una categoría, para
/// proponer un límite con datos reales en vez de inventar la cifra. `null`
/// cuando todavía no hay historial.
final promedioCategoriaProvider = Provider.family<double?, String>((
  ref,
  categoria,
) {
  final movimientos =
      ref.watch(movimientosStreamProvider).asData?.value ??
      const <Transaction>[];
  final periodo = ref.watch(periodoVisibleProvider);
  return GastosLogic.promedioMensualCategoria(
    movimientos: movimientos,
    categoria: categoria,
    mes: periodo.mes,
    anio: periodo.anio,
  );
});

/// Total presupuestado y gastado del mes visible, para el encabezado. Solo
/// cuenta las categorías con presupuesto: es el plan contra la realidad.
class TotalesPresupuesto {
  final double presupuestado;
  final double gastado;

  const TotalesPresupuesto({
    required this.presupuestado,
    required this.gastado,
  });

  double get disponible => presupuestado - gastado;

  bool get superado => gastado > presupuestado;

  double get porcentaje {
    if (presupuestado <= 0) return gastado > 0 ? 100 : 0;
    return (gastado / presupuestado) * 100;
  }
}

final totalesPresupuestoProvider = FutureProvider<TotalesPresupuesto>((
  ref,
) async {
  final resumenes = await ref.watch(resumenesPresupuestoProvider.future);
  var presupuestado = 0.0;
  var gastado = 0.0;
  for (final resumen in resumenes) {
    presupuestado += resumen.limite;
    gastado += resumen.gastado;
  }
  return TotalesPresupuesto(
    presupuestado: presupuestado,
    gastado: gastado,
  );
});
