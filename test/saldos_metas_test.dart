import 'package:fitki/data/models/abono_meta.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/logic/activos/activos_logic.dart';
import 'package:fitki/logic/metas/metas_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de la regla de los dos saldos.
///
/// Un activo tiene un **Saldo Total** (todo el dinero de la cuenta, que solo
/// mueven ingresos y gastos) y un **Saldo Disponible** (el total menos lo
/// apartado en metas). Una meta tiene su propio saldo, que es la suma con signo
/// de sus aportes y retiros.
///
/// Acá se testea la aritmética de esa regla, que es pura y no necesita base de
/// datos. Son justamente los números que el usuario usa para decidir si puede
/// gastar: si esta lógica miente, la app lo lleva a gastar dinero que ya
/// prometió guardar.

AbonoMeta _registro({
  int? id,
  int metaId = 1,
  required String tipo,
  required double monto,
  int? activoId = 1,
}) {
  return AbonoMeta(
    id: id,
    metaId: metaId,
    tipo: tipo,
    monto: monto,
    fecha: DateTime(2026, 3, 12),
    activoId: activoId,
    fechaCreacion: DateTime(2026, 3, 12),
  );
}

/// [objetivo] es nullable a propósito: `MetasLogic` distingue "sin objetivo fijo"
/// (`montoObjetivo == null`) de "objetivo cero" (`montoObjetivo == 0`), que son
/// dos cosas distintas. Con un `objetivo` no-nullable el test no podía
/// nombrar el primer caso y lo cubría con el segundo.
FinancialGoal _meta({int id = 1, double? objetivo = 1000, double saldo = 0}) {
  return FinancialGoal(
    id: id,
    nombre: 'Viaje',
    montoObjetivo: objetivo,
    montoAhorrado: saldo,
    finalidad: 'viaje',
    comentarios: null,
    fechaEstimada: null,
    fechaCreacion: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ActivosLogic.saldoReservadoEn', () {
    test('suma solo los registros de esa cuenta', () {
      final registros = [
        _registro(id: 1, tipo: AbonoMeta.tipoAporte, monto: 200, activoId: 1),
        _registro(id: 2, tipo: AbonoMeta.tipoAporte, monto: 50, activoId: 2),
        _registro(id: 3, tipo: AbonoMeta.tipoRetiro, monto: 30, activoId: 1),
      ];

      expect(ActivosLogic.saldoReservadoEn(1, registros), 170);
      expect(ActivosLogic.saldoReservadoEn(2, registros), 50);
    });

    test('el saldo reservado puede ser 0 aunque tenga aportes y retiros', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 100),
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 100),
      ];

      expect(ActivosLogic.saldoReservadoEn(1, registros), 0);
    });

    test('sin cuenta no hay reserva, y sin registros tampoco', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 100, activoId: null),
      ];

      expect(ActivosLogic.saldoReservadoEn(null, registros), 0);
      expect(ActivosLogic.saldoReservadoEn(1, registros), 0);
      expect(ActivosLogic.saldoReservadoEn(1, const []), 0);
    });
  });

  group('ActivosLogic.saldoDisponible', () {
    test('es el total menos lo reservado', () {
      expect(ActivosLogic.saldoDisponible(1000, 300), 700);
    });

    test('sin reservas es igual al total', () {
      expect(ActivosLogic.saldoDisponible(1000, 0), 1000);
    });

// Un recorte a cero haría creer que todavía se puede gastar lo que ya se
    // prometió guardar, que es justo el error que el saldo disponible existe
    // para evitar.
    test('no se recorta a cero: una reserva mayor que el total queda en negativo', () {
      expect(ActivosLogic.saldoDisponible(100, 300), -200);
    });
  });

  group('MetasLogic.saldoDeMeta', () {
    test('es aportes menos retiros', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 500),
        _registro(tipo: AbonoMeta.tipoAporte, monto: 200),
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 150),
      ];

      expect(MetasLogic.saldoDeMeta(registros), 550);
    });

    test('sin registros vale 0, no null', () {
      expect(MetasLogic.saldoDeMeta(const []), 0);
    });

    test('aportar y retirar todo deja la meta en 0', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 900),
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 900),
      ];

      expect(MetasLogic.saldoDeMeta(registros), 0);
    });
  });

  group('MetasLogic.reservadoEnActivo', () {
    test('cuenta solo lo que salió de esa cuenta', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 400, activoId: 1),
        _registro(tipo: AbonoMeta.tipoAporte, monto: 700, activoId: 2),
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 100, activoId: 1),
      ];

      expect(MetasLogic.reservadoEnActivo(registros, 1), 300);
      expect(MetasLogic.reservadoEnActivo(registros, 2), 700);
    });

    test('retirar más de lo que se apartó desde esa cuenta queda en negativo', () {
      // Es el caso que la validación del repositorio impide, pero la aritmética
      // no lo esconde: si algún camino lo dejara pasar, el saldo disponible se
      // vería inflado.
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 100, activoId: 1),
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 250, activoId: 1),
      ];

      expect(MetasLogic.reservadoEnActivo(registros, 1), -150);
    });
  });

  group('MetasLogic.calcular', () {
    test('con registros, el saldo viene del historial y no del campo acumulado', () {
      // El campo acumulado dice 1000 pero el historial solo suma 300. La pantalla
      // tiene que mostrar 300: si confiara en el campo acumulado, el avance de la meta
      // podría no cuadrar con los aportes que el usuario ve debajo.
      final meta = _meta(saldo: 1000);
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 300),
      ];

      final calculo = MetasLogic.calcular(meta, registros: registros);

      expect(calculo.saldo, 300);
      expect(calculo.montoFaltante, 700);
      expect(calculo.porcentajeProgreso, closeTo(30, 0.001));
    });

    test('sin registros, cae al acumulado guardado', () {
      final calculo = MetasLogic.calcular(_meta(saldo: 400));

      expect(calculo.saldo, 400);
    });

    test('retiros restan del avance', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 800),
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 300),
      ];

      final calculo = MetasLogic.calcular(_meta(), registros: registros);

      expect(calculo.saldo, 500);
      expect(calculo.porcentajeProgreso, closeTo(50, 0.001));
    });

    test('superar el objetivo no da progreso negativo ni supera el 100%', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 1500),
      ];

      final calculo = MetasLogic.calcular(_meta(objetivo: 1000), registros: registros);

      expect(calculo.saldo, 1500);
      expect(calculo.montoFaltante, 0);
      expect(calculo.porcentajeProgreso, 100);
      expect(calculo.cumpleObjetivo, isTrue);
    });

    test('sin objetivo fijo no hay faltante ni progreso, y no se cumple', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 500),
      ];

      final calculo = MetasLogic.calcular(
        _meta(objetivo: null),
        registros: registros,
      );

      expect(calculo.saldo, 500);
      // Sin objetivo no hay nada que faltar: `montoFaltante` es `null`, no 0.
      expect(calculo.montoFaltante, isNull);
      expect(calculo.porcentajeProgreso, 0);
      expect(calculo.cumpleObjetivo, isFalse);
    });

    test('un objetivo de cero se alcanza solo y no arrastra progreso', () {
      final registros = [
        _registro(tipo: AbonoMeta.tipoAporte, monto: 500),
      ];

      final calculo = MetasLogic.calcular(
        _meta(objetivo: 0),
        registros: registros,
      );

      expect(calculo.saldo, 500);
      // 0 - 500 queda recortado a 0: el objetivo ya está cubierto.
      expect(calculo.montoFaltante, 0);
      // Dividir por cero no es progreso 100: la barra queda en 0.
      expect(calculo.porcentajeProgreso, 0);
      expect(calculo.cumpleObjetivo, isTrue);
    });
  });

  group('AbonoMeta', () {
    test('el monto con signo distingue aporte de retiro', () {
      expect(
        _registro(tipo: AbonoMeta.tipoAporte, monto: 100).montoConSigno,
        100,
      );
      expect(
        _registro(tipo: AbonoMeta.tipoRetiro, monto: 100).montoConSigno,
        -100,
      );
    });

    test('esAporte reconoce solo el tipo aporte', () {
      expect(_registro(tipo: AbonoMeta.tipoAporte, monto: 1).esAporte, isTrue);
      expect(_registro(tipo: AbonoMeta.tipoRetiro, monto: 1).esAporte, isFalse);
    });
  });
}