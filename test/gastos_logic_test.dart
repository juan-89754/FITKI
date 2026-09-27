import 'package:fitki/data/models/gasto_fijo.dart';
import 'package:fitki/data/models/pago_gasto_fijo.dart';
import 'package:fitki/data/models/presupuesto_activo.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/logic/gastos/gastos_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de la lógica pura de gastos.
///
/// `GastosLogic` no toca base de datos ni widgets, así que se puede testear
/// entero sin emulador. Acá vive la aritmética que el usuario ve: cuánto se
/// gastó, cuánto quedó, cuánto se pasó y cuánto se precarga al pagar. Un error
/// acá no rompe la app, la hace mentir con los números, que es peor.

GastoFijo _plantilla({
  int? id = 1,
  String nombre = 'Internet',
  String categoria = 'servicios',
  double monto = 30000,
  int diaPago = 10,
  int? activoId = 1,
  bool variable = false,
  bool habilitado = true,
  DateTime? fechaInicio,
  DateTime? fechaFin,
}) {
  return GastoFijo(
    id: id,
    nombre: nombre,
    categoria: categoria,
    montoEstimado: monto,
    diaPago: diaPago,
    activoId: activoId,
    montoVariable: variable,
    habilitado: habilitado,
    fechaInicio: fechaInicio ?? DateTime(2026, 1, 1),
    fechaFin: fechaFin,
    fechaCreacion: DateTime(2026, 1, 1),
  );
}

PagoGastoFijo _pago({
  int id = 1,
  int gastoFijoId = 1,
  int mes = 3,
  int anio = 2026,
  double estimado = 30000,
  double? pagado,
}) {
  return PagoGastoFijo(
    id: id,
    gastoFijoId: gastoFijoId,
    mes: mes,
    anio: anio,
    montoEstimado: estimado,
    montoPagado: pagado,
    fechaPago: pagado == null ? null : DateTime(anio, mes, 10),
    fechaCreacion: DateTime(anio, mes, 1),
  );
}

Transaction _movimiento({
  required int activoId,
  required double monto,
  String tipo = Transaction.tipoGasto,
  String categoria = 'alimentacion',
  DateTime? fecha,
}) {
  return Transaction(
    tipo: tipo,
    monto: monto,
    categoria: categoria,
    fecha: fecha ?? DateTime(2026, 3, 15),
    activoId: activoId,
    fechaCreacion: DateTime(2026, 3, 15),
  );
}

PresupuestoActivo _presupuesto({
  int activoId = 1,
  int mes = 3,
  int anio = 2026,
  required double limite,
}) {
  return PresupuestoActivo(
    activoId: activoId,
    mes: mes,
    anio: anio,
    montoLimite: limite,
    fechaCreacion: DateTime(2026, 3, 1),
  );
}

void main() {
  group('pagosPendientesDeGenerar', () {
    test('genera un pago por cada plantilla vigente del mes', () {
      final nuevos = GastosLogic.pagosPendientesDeGenerar(
        plantillas: [
          _plantilla(id: 1, nombre: 'Internet'),
          _plantilla(id: 2, nombre: 'Arriendo', monto: 500000),
        ],
        yaExistentes: const [],
        mes: 3,
        anio: 2026,
        ahora: DateTime(2026, 3, 1),
      );

      expect(nuevos, hasLength(2));
      expect(nuevos.map((p) => p.gastoFijoId), containsAll([1, 2]));
      // El estimado se copia de la plantilla en el momento de generar.
      expect(nuevos.firstWhere((p) => p.gastoFijoId == 2).montoEstimado, 500000);
    });

    test('es idempotente: repetir la generación no duplica pagos', () {
      // Es la garantía que hace segura la generación automática: la app
      // regenera el mes cada vez que se abre la pantalla.
      final primera = GastosLogic.pagosPendientesDeGenerar(
        plantillas: [_plantilla(id: 1)],
        yaExistentes: const [],
        mes: 3,
        anio: 2026,
        ahora: DateTime(2026, 3, 1),
      );
      final segunda = GastosLogic.pagosPendientesDeGenerar(
        plantillas: [_plantilla(id: 1)],
        yaExistentes: primera,
        mes: 3,
        anio: 2026,
        ahora: DateTime(2026, 3, 1),
      );

      expect(segunda, isEmpty);
    });

    test('ignora pagos de otros meses al decidir qué falta', () {
      // Un pago de FEBRERO no puede hacer creer que marzo ya está cubierto.
      final nuevos = GastosLogic.pagosPendientesDeGenerar(
        plantillas: [_plantilla(id: 1)],
        yaExistentes: [_pago(mes: 2, anio: 2026)],
        mes: 3,
        anio: 2026,
        ahora: DateTime(2026, 3, 1),
      );

      expect(nuevos, hasLength(1));
    });

    test('no genera para plantillas pausadas ni fuera de su vigencia', () {
      final nuevos = GastosLogic.pagosPendientesDeGenerar(
        plantillas: [
          _plantilla(id: 1, nombre: 'Pausada', habilitado: false),
          _plantilla(
            id: 2,
            nombre: 'Ya terminada',
            fechaInicio: DateTime(2025, 1, 1),
            fechaFin: DateTime(2025, 12, 31),
          ),
          _plantilla(id: 3, nombre: 'Futura', fechaInicio: DateTime(2026, 6, 1)),
        ],
        yaExistentes: const [],
        mes: 3,
        anio: 2026,
        ahora: DateTime(2026, 3, 1),
      );

      expect(nuevos, isEmpty);
    });

    test('salta plantillas sin id (aún no guardadas)', () {
      final nuevos = GastosLogic.pagosPendientesDeGenerar(
        plantillas: [_plantilla(id: null)],
        yaExistentes: const [],
        mes: 3,
        anio: 2026,
        ahora: DateTime(2026, 3, 1),
      );

      expect(nuevos, isEmpty);
    });
  });

  group('estimarMontoPagado', () {
    test('promedia los últimos pagos confirmados', () {
      final promedio = GastosLogic.estimarMontoPagado([
        _pago(id: 1, mes: 1, pagado: 10000),
        _pago(id: 2, mes: 2, pagado: 20000),
        _pago(id: 3, mes: 3, pagado: 30000),
      ]);

      expect(promedio, 20000);
    });

    test('ignora los pagos pendientes y usa solo hasta 3 muestras', () {
      final promedio = GastosLogic.estimarMontoPagado([
        _pago(id: 1, mes: 1, pagado: 10000),
        _pago(id: 2, mes: 2, pagado: 30000),
        _pago(id: 3, mes: 3, pagado: 50000),
        _pago(id: 4, mes: 4, pagado: 90000),
        _pago(id: 5, mes: 5), // pendiente: no entra
      ]);

      // Promedia los 3 primeros = 30000, e ignora el cuarto.
      expect(promedio, 30000);
    });

    test('devuelve null sin historial, para que la app use el estimado', () {
      expect(GastosLogic.estimarMontoPagado(const []), isNull);
      expect(GastosLogic.estimarMontoPagado([_pago()]), isNull);
    });
  });

  group('pendientesDelMes', () {
    test('un gasto variable usa el promedio del historial', () {
      final plantilla = _plantilla(id: 1, variable: true, monto: 30000);
      final resultado = GastosLogic.pendientesDelMes(
        pagos: [_pago(gastoFijoId: 1, mes: 3, estimado: 30000)],
        historial: [
          _pago(id: 10, gastoFijoId: 1, mes: 1, pagado: 50000),
          _pago(id: 11, gastoFijoId: 1, mes: 2, pagado: 70000),
        ],
        plantillasPorId: {1: plantilla},
        hoy: DateTime(2026, 3, 5),
      );

      expect(resultado, hasLength(1));
      expect(resultado.single.montoSugerido, 60000);
    });

    test('sin historial, un variable cae a su estimado', () {
      final resultado = GastosLogic.pendientesDelMes(
        pagos: [_pago(gastoFijoId: 1, mes: 3, estimado: 30000)],
        historial: const [],
        plantillasPorId: {1: _plantilla(id: 1, variable: true, monto: 30000)},
        hoy: DateTime(2026, 3, 5),
      );

      expect(resultado.single.montoSugerido, 30000);
    });

    test('un gasto fijo nunca se promedia, siempre su estimado', () {
      final resultado = GastosLogic.pendientesDelMes(
        pagos: [_pago(gastoFijoId: 1, mes: 3, estimado: 30000)],
        historial: [_pago(id: 10, gastoFijoId: 1, mes: 2, pagado: 99999)],
        plantillasPorId: {1: _plantilla(id: 1, variable: false, monto: 30000)},
        hoy: DateTime(2026, 3, 5),
      );

      expect(resultado.single.montoSugerido, 30000);
    });

    test('excluye lo ya pagado y ordena por fecha de pago', () {
      final resultado = GastosLogic.pendientesDelMes(
        pagos: [
          _pago(id: 1, gastoFijoId: 2, mes: 3),
          _pago(id: 2, gastoFijoId: 1, mes: 3),
          _pago(id: 3, gastoFijoId: 3, mes: 3, pagado: 100),
        ],
        historial: const [],
        plantillasPorId: {
          // El 1 paga el 25 y el 2 el 5: el orden final debe ser 2, 1.
          1: _plantilla(id: 1, diaPago: 25),
          2: _plantilla(id: 2, diaPago: 5),
          3: _plantilla(id: 3, diaPago: 1),
        },
        hoy: DateTime(2026, 3, 5),
      );

      expect(resultado.map((p) => p.plantilla.id), [2, 1]);
    });

    test('marca requiereActivo cuando se borró la cuenta de la plantilla', () {
      final resultado = GastosLogic.pendientesDelMes(
        pagos: [_pago(gastoFijoId: 1, mes: 3)],
        historial: const [],
        plantillasPorId: {1: _plantilla(id: 1, activoId: null)},
        hoy: DateTime(2026, 3, 5),
      );

      expect(resultado.single.requiereActivo, isTrue);
    });
  });

  group('compararPresupuesto y excedente', () {
    test('suma solo los gastos del activo en el mes', () {
      final resumen = GastosLogic.compararPresupuesto(
        presupuesto: _presupuesto(limite: 100000),
        movimientos: [
          _movimiento(activoId: 1, monto: 30000),
          _movimiento(activoId: 1, monto: 20000, fecha: DateTime(2026, 3, 28)),
          // De otra cuenta: no va a este presupuesto.
          _movimiento(activoId: 2, monto: 90000),
          // De otro mes: tampoco.
          _movimiento(activoId: 1, monto: 50000, fecha: DateTime(2026, 2, 10)),
          // Un ingreso del mismo activo tampoco es gasto.
          _movimiento(
            activoId: 1,
            monto: 70000,
            tipo: Transaction.tipoIngreso,
          ),
        ],
      );

      expect(resumen.gastado, 50000);
      expect(resumen.superado, isFalse);
      expect(resumen.restante, 50000);
      expect(resumen.excedido, 0);
    });

    test('marca superado y reparte el restante en cero y el excedente', () {
      final resumen = GastosLogic.compararPresupuesto(
        presupuesto: _presupuesto(limite: 100000),
        movimientos: [_movimiento(activoId: 1, monto: 140000)],
      );

      expect(resumen.superado, isTrue);
      // El restante nunca se muestra negativo: la app informa el excedente.
      expect(resumen.restante, 0);
      expect(resumen.excedido, 40000);
    });

    test('calcula el porcentaje sobre el límite', () {
      final resumen = GastosLogic.compararPresupuesto(
        presupuesto: _presupuesto(limite: 200000),
        movimientos: [_movimiento(activoId: 1, monto: 50000)],
      );

      expect(resumen.porcentaje, 25);
    });

    test('un límite en cero no divide por cero', () {
      final conGasto = GastosLogic.compararPresupuesto(
        presupuesto: _presupuesto(limite: 0),
        movimientos: [_movimiento(activoId: 1, monto: 10000)],
      );
      final sinGasto = GastosLogic.compararPresupuesto(
        presupuesto: _presupuesto(limite: 0),
        movimientos: const [],
      );

      expect(conGasto.porcentaje, 100);
      expect(sinGasto.porcentaje, 0);
    });

    test('el gasto puede superar el saldo de la cuenta sin recortarse', () {
      // Regresión del clamp: una cuenta puede quedar en negativo y el
      // presupuesto debe seguir reportando el gasto REAL, no el recortado.
      final resumen = GastosLogic.compararPresupuesto(
        presupuesto: _presupuesto(limite: 100000),
        movimientos: [_movimiento(activoId: 1, monto: 500000)],
      );

      expect(resumen.gastado, 500000);
      expect(resumen.excedido, 400000);
    });
  });

  group('desglosePorCategoria', () {
    test('agrupa, ordena de mayor a menor y reparte porcentajes', () {
      final renglones = GastosLogic.desglosePorCategoria([
        _movimiento(activoId: 1, monto: 20000, categoria: 'alimentacion'),
        _movimiento(activoId: 1, monto: 50000, categoria: 'servicios'),
        _movimiento(activoId: 1, monto: 30000, categoria: 'alimentacion'),
      ]);

      expect(renglones.map((r) => r.categoria), ['alimentacion', 'servicios']);
      expect(renglones.first.monto, 50000);
      expect(renglones.first.porcentaje, closeTo(50, 0.001));
      expect(renglones.last.porcentaje, closeTo(50, 0.001));
    });

    test('ignora ingresos', () {
      final renglones = GastosLogic.desglosePorCategoria([
        _movimiento(
          activoId: 1,
          monto: 90000,
          tipo: Transaction.tipoIngreso,
          categoria: 'sueldo',
        ),
      ]);

      expect(renglones, isEmpty);
    });
  });

  group('gastadoPorActivo', () {
    test('acumula por activo solo en el mes pedido', () {
      final resultado = GastosLogic.gastadoPorActivo(
        movimientos: [
          _movimiento(activoId: 1, monto: 10000),
          _movimiento(activoId: 1, monto: 15000, fecha: DateTime(2026, 3, 30)),
          _movimiento(activoId: 2, monto: 20000),
          _movimiento(activoId: 1, monto: 80000, fecha: DateTime(2026, 1, 5)),
        ],
        mes: 3,
        anio: 2026,
      );

      expect(resultado[1], 25000);
      expect(resultado[2], 20000);
    });
  });

  group('totales', () {
    test('totalPendiente cuenta lo no pagado y totalPagadoDelMes lo pagado', () {
      final pagos = [
        _pago(id: 1, estimado: 30000),
        _pago(id: 2, estimado: 20000, pagado: 18000),
      ];

      expect(GastosLogic.totalPendiente(pagos), 30000);
      expect(GastosLogic.totalPagadoDelMes(pagos), 18000);
    });
  });
}
