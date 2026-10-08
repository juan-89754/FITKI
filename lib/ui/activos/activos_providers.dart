import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/abono_meta.dart';
import '../../data/models/asset.dart';
import '../../data/models/investment.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/activos/activos_logic.dart';
import '../metas/metas_providers.dart';
import '../prestamos_inversiones/prestamos_inversiones_providers.dart';

final patrimonioProvider = Provider<List<PatrimonioPorMoneda>>((ref) {
  final activos = ref.watch(activosStreamProvider).asData?.value ?? [];
  return ActivosLogic.calcularPatrimonioPorMoneda(activos);
});

/// El patrimonio es la suma de los Saldos **Totales**: incluye el dinero que está
/// apartado en metas, porque ese dinero sigue siendo tuyo y sigue en la cuenta.
/// Para saber qué se puede gastar, ver [patrimonioDisponibleTotalProvider].
final patrimonioTotalProvider = Provider<double>((ref) {
  final activos = ref.watch(activosStreamProvider).asData?.value ?? [];
  return ActivosLogic.calcularPatrimonioTotal(activos);
});

/// Activos con su Saldo Disponible calculado.
final activosConSaldoProvider = Provider<List<ActivoConSaldo>>((ref) {
  final activos = ref.watch(activosStreamProvider).asData?.value ?? [];
  final registros = ref.watch(registrosDeMetasProvider).asData?.value ?? [];
  final inversiones =
      ref.watch(inversionesStreamProvider).asData?.value ?? const <Investment>[];

  return activos
      .map((activo) => ActivoConSaldo.create(activo, registros, inversiones))
      .toList();
});

/// Suma de los Saldos Disponibles: el dinero que todavía se puede gastar.
final patrimonioDisponibleTotalProvider = Provider<double>((ref) {
  return ref
      .watch(activosConSaldoProvider)
      .fold<double>(0, (suma, activo) => suma + activo.saldoDisponible);
});

/// Un activo con sus dos saldos.
///
/// - **Saldo Total**: todo el dinero de la cuenta. Lo mueven ingresos y gastos.
/// - **Saldo Disponible**: el total menos lo reservado en metas. Es el único
///   saldo contra el que tiene sentido comparar un presupuesto o un límite de
///   gasto.
class ActivoConSaldo {
  final Asset activo;
  final double saldoTotal;
  final double reservado;
  final double reservadoInversiones;
  final double saldoDisponible;

  const ActivoConSaldo({
    required this.activo,
    required this.saldoTotal,
    required this.reservado,
    required this.reservadoInversiones,
    required this.saldoDisponible,
  });

  factory ActivoConSaldo.create(
    Asset activo,
    List<AbonoMeta> registros, [
    List<Investment> inversiones = const [],
  ]) {
    final reservado = ActivosLogic.saldoReservadoEn(activo.id, registros);
    final reservadoInversiones =
        ActivosLogic.saldoReservadoInversionesEn(activo.id, inversiones);
    return ActivoConSaldo(
      activo: activo,
      saldoTotal: activo.montoDisponible,
      reservado: reservado,
      reservadoInversiones: reservadoInversiones,
      saldoDisponible: ActivosLogic.saldoDisponible(
        activo.montoDisponible,
        reservado,
        reservadoInversiones: reservadoInversiones,
      ),
    );
  }

  int get id => activo.id!;
  String get nombre => activo.nombre;
  String get moneda => activo.moneda;
}