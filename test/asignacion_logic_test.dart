import 'package:fitki/data/models/detalle_asignacion.dart';
import 'package:fitki/data/models/plan_asignacion.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/logic/asignaciones/asignacion_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de la lógica pura del módulo AFCA.
///
/// `AsignacionLogic` no toca base de datos ni widgets, así que se puede testear
/// entero sin emulador. Acá vive la aritmética que el usuario ve: cuánto del
/// plan ya tiene destino, cuánto se gastó en cada bolsillo y a qué bolsillo le
/// toca un gasto nuevo. Un error acá no rompe la app, la hace mentir con los
/// números, que es peor.

PlanAsignacion _plan({
  int? id,
  int? activoId = 1,
  String nombre = 'Quincena',
  double monto = 100000,
  bool esProyectado = false,
  bool archivado = false,
}) {
  return PlanAsignacion(
    id: id,
    activoId: activoId,
    nombre: nombre,
    montoTotalObjetivo: monto,
    esProyectado: esProyectado,
    archivado: archivado,
    fechaCreacion: DateTime(2026, 3, 1),
  );
}

DetalleAsignacion _bolsillo({
  int? id,
  int? planId = 1,
  String categoria = 'alimentacion',
  double monto = 50000,
}) {
  return DetalleAsignacion(
    id: id,
    planId: planId,
    categoria: categoria,
    montoAsignado: monto,
  );
}

Transaction _movimiento({
  int? activoId = 1,
  double monto = 1000,
  String tipo = Transaction.tipoGasto,
  String categoria = 'alimentacion',
  int? planDetalleId,
  DateTime? fecha,
}) {
  return Transaction(
    tipo: tipo,
    monto: monto,
    categoria: categoria,
    fecha: fecha ?? DateTime(2026, 3, 15),
    activoId: activoId,
    planDetalleId: planDetalleId,
    fechaCreacion: DateTime(2026, 3, 15),
  );
}

/// Resúmenes de un plan con sus bolsillos, tal como los arma la app.
List<ResumenPlan> _resumenes({
  required PlanAsignacion plan,
  required List<DetalleAsignacion> detalles,
  List<Transaction> movimientos = const [],
}) {
  return [
    AsignacionLogic.resumirPlan(
      plan: plan,
      detalles: detalles,
      movimientos: movimientos,
    ),
  ];
}

void main() {
  group('dineroSinAsignar', () {
    test('resta a lo asignado a los bolsillos', () {
      final sinAsignar = AsignacionLogic.dineroSinAsignar(
        _plan(monto: 100000),
        [_bolsillo(monto: 60000), _bolsillo(monto: 20000)],
      );
      expect(sinAsignar, 20000);
    });

    test('puede ser negativo si se asignó de más', () {
      final sinAsignar = AsignacionLogic.dineroSinAsignar(
        _plan(monto: 30000),
        [_bolsillo(monto: 50000)],
      );
      expect(sinAsignar, -20000);
    });

    test('sin bolsillos devuelve el objetivo entero', () {
      final sinAsignar = AsignacionLogic.dineroSinAsignar(
        _plan(monto: 45000),
        const [],
      );
      expect(sinAsignar, 45000);
    });
  });

  group('gastadoDeDetalle', () {
    test('suma solo los gastos vinculados a ese bolsillo', () {
      final gastado = AsignacionLogic.gastadoDeDetalle(
        _bolsillo(id: 7),
        [
          _movimiento(monto: 3000, planDetalleId: 7),
          _movimiento(monto: 1500, planDetalleId: 7),
          // De otro bolsillo: no cuenta.
          _movimiento(monto: 9000, planDetalleId: 8),
          // Sin vínculo: tampoco es de este bolsillo.
          _movimiento(monto: 4000),
        ],
      );
      expect(gastado, 4500);
    });

    test('un ingreso vinculado no suma: solo los gastos', () {
      final gastado = AsignacionLogic.gastadoDeDetalle(
        _bolsillo(id: 7),
        [
          _movimiento(monto: 3000, planDetalleId: 7),
          _movimiento(
            monto: 8000,
            tipo: Transaction.tipoIngreso,
            planDetalleId: 7,
          ),
        ],
      );
      expect(gastado, 3000);
    });

    test('un bolsillo sin id nunca gastó', () {
      // Sin id no puede haber movimiento apuntando a él, y contar en cero es
      // mejor que inventar un vínculo.
      final gastado = AsignacionLogic.gastadoDeDetalle(
        _bolsillo(id: null),
        [_movimiento(monto: 3000)],
      );
      expect(gastado, 0);
    });
  });

  group('movimientosDeDetalle', () {
    test('devuelve solo los gastos vinculados a ese bolsillo', () {
      final movimientos = AsignacionLogic.movimientosDeDetalle(7, [
        _movimiento(monto: 3000, planDetalleId: 7),
        _movimiento(monto: 1500, planDetalleId: 7),
        // De otro bolsillo: no aparece.
        _movimiento(monto: 9000, planDetalleId: 8),
        // Sin vínculo: tampoco.
        _movimiento(monto: 4000),
        // Un ingreso vinculado no es un gasto del bolsillo.
        _movimiento(
          monto: 8000,
          tipo: Transaction.tipoIngreso,
          planDetalleId: 7,
        ),
      ]);
      expect(movimientos, hasLength(2));
      expect(movimientos.map((m) => m.monto), [3000, 1500]);
    });

    test('los ordena del más reciente al más viejo', () {
      final movimientos = AsignacionLogic.movimientosDeDetalle(7, [
        _movimiento(
          monto: 1000,
          planDetalleId: 7,
          fecha: DateTime(2026, 3, 10),
        ),
        _movimiento(
          monto: 2000,
          planDetalleId: 7,
          fecha: DateTime(2026, 5, 1),
        ),
        _movimiento(
          monto: 3000,
          planDetalleId: 7,
          fecha: DateTime(2026, 1, 20),
        ),
      ]);
      expect(movimientos.map((m) => m.monto), [2000, 1000, 3000]);
    });

    test('sin movimientos vinculados devuelve una lista vacía', () {
      final movimientos = AsignacionLogic.movimientosDeDetalle(7, [
        _movimiento(monto: 3000, planDetalleId: 8),
      ]);
      expect(movimientos, isEmpty);
    });
  });

  group('resumirPlan', () {
    test('arma un resumen por bolsillo con su gasto derivado', () {
      final resumen = AsignacionLogic.resumirPlan(
        plan: _plan(monto: 100000),
        detalles: [
          _bolsillo(id: 1, monto: 60000),
          _bolsillo(id: 2, categoria: 'transporte', monto: 40000),
        ],
        movimientos: [
          _movimiento(monto: 25000, planDetalleId: 1),
          _movimiento(
            monto: 5000,
            categoria: 'transporte',
            planDetalleId: 2,
          ),
        ],
      );

      expect(resumen.detalles, hasLength(2));
      expect(resumen.detalles[0].categoria, 'alimentacion');
      expect(resumen.detalles[0].gastado, 25000);
      expect(resumen.detalles[0].restante, 35000);
      expect(resumen.detalles[1].gastado, 5000);

      expect(resumen.totalObjetivo, 100000);
      expect(resumen.totalAsignado, 100000);
      expect(resumen.sinAsignar, 0);
      expect(resumen.cuadrado, isTrue);
      expect(resumen.gastadoTotal, 30000);
    });

    test('marca excedido al pasar el gasto del asignado', () {
      final resumen = AsignacionLogic.resumirPlan(
        plan: _plan(monto: 10000),
        detalles: [_bolsillo(id: 1, monto: 10000)],
        movimientos: [_movimiento(monto: 12000, planDetalleId: 1)],
      );

      final detalle = resumen.detalles.single;
      expect(detalle.excedido, 2000);
      expect(detalle.restante, 0, reason: 'el restante no baja de cero');
      expect(detalle.superado, isTrue);
    });
  });

  group('gastadoNoPresupuestado', () {
    test('suma los gastos que no llevan vínculo', () {
      final total = AsignacionLogic.gastadoNoPresupuestado([
        _movimiento(monto: 2000),
        _movimiento(monto: 3000),
        // Vinculado a un bolsillo: ese gasto ya tiene destino.
        _movimiento(monto: 9000, planDetalleId: 4),
        // Un ingreso no es gasto.
        _movimiento(monto: 50000, tipo: Transaction.tipoIngreso),
      ]);
      expect(total, 5000);
    });
  });

  group('gastadoNoPresupuestadoDelMes', () {
    test('solo cuenta los gastos sin vínculo del mes pedido', () {
      final total = AsignacionLogic.gastadoNoPresupuestadoDelMes(
        [
          _movimiento(monto: 2000, fecha: DateTime(2026, 3, 5)),
          _movimiento(monto: 3000, fecha: DateTime(2026, 3, 20)),
          // Otro mes: no cuenta.
          _movimiento(monto: 8000, fecha: DateTime(2026, 4, 1)),
          // Vinculado: no es "fuera de plan".
          _movimiento(
            monto: 9000,
            planDetalleId: 4,
            fecha: DateTime(2026, 3, 10),
          ),
        ],
        referencia: DateTime(2026, 3, 15),
      );
      expect(total, 5000);
    });

    test('sin gastos fuera de plan devuelve cero', () {
      final total = AsignacionLogic.gastadoNoPresupuestadoDelMes(
        [_movimiento(monto: 9000, planDetalleId: 4)],
        referencia: DateTime(2026, 3, 15),
      );
      expect(total, 0);
    });
  });

  group('ResumenPlan.porcentajeUsado', () {
    test('es el gasto total sobre lo asignado', () {
      final resumen = AsignacionLogic.resumirPlan(
        plan: _plan(id: 1),
        detalles: [
          _bolsillo(id: 1, monto: 40000, categoria: 'alimentacion'),
          _bolsillo(id: 2, monto: 60000, categoria: 'transporte'),
        ],
        movimientos: [
          _movimiento(monto: 25000, planDetalleId: 1),
          _movimiento(monto: 15000, planDetalleId: 2),
        ],
      );
      expect(resumen.porcentajeUsado, 40);
    });

    test('sin dinero asignado no hay porcentaje que mostrar', () {
      final resumen = AsignacionLogic.resumirPlan(
        plan: _plan(id: 1),
        detalles: const [],
        movimientos: const [],
      );
      expect(resumen.porcentajeUsado, 0);
    });

    test('puede pasar de 100% cuando se gasta de más', () {
      final resumen = AsignacionLogic.resumirPlan(
        plan: _plan(id: 1),
        detalles: [_bolsillo(id: 1, monto: 10000)],
        movimientos: [_movimiento(monto: 15000, planDetalleId: 1)],
      );
      expect(resumen.porcentajeUsado, 150);
    });
  });

  group('repartoPorCategoria', () {
    test('suma los bolsillos de la misma categoría entre planes', () {
      final reparto = AsignacionLogic.repartoPorCategoria([
        AsignacionLogic.resumirPlan(
          plan: _plan(id: 1, nombre: 'Quincena'),
          detalles: [_bolsillo(id: 1, monto: 30000)],
          movimientos: [_movimiento(monto: 10000, planDetalleId: 1)],
        ),
        AsignacionLogic.resumirPlan(
          plan: _plan(id: 2, nombre: 'Viaje'),
          detalles: [_bolsillo(id: 2, monto: 20000)],
          movimientos: [_movimiento(monto: 5000, planDetalleId: 2)],
        ),
      ]);
      expect(reparto, hasLength(1));
      expect(reparto.first.categoria, 'alimentacion');
      expect(reparto.first.asignado, 50000);
      expect(reparto.first.gastado, 15000);
    });

    test('ordena de mayor a menor asignado', () {
      final reparto = AsignacionLogic.repartoPorCategoria([
        AsignacionLogic.resumirPlan(
          plan: _plan(id: 1),
          detalles: [
            _bolsillo(id: 1, monto: 10000, categoria: 'transporte'),
            _bolsillo(id: 2, monto: 40000, categoria: 'alimentacion'),
            _bolsillo(id: 3, monto: 25000, categoria: 'salud'),
          ],
          movimientos: const [],
        ),
      ]);
      expect(
        reparto.map((r) => r.categoria),
        ['alimentacion', 'salud', 'transporte'],
      );
    });

    test('deja fuera los planes archivados', () {
      final reparto = AsignacionLogic.repartoPorCategoria([
        AsignacionLogic.resumirPlan(
          plan: _plan(id: 1, archivado: true),
          detalles: [_bolsillo(id: 1, monto: 30000)],
          movimientos: const [],
        ),
        AsignacionLogic.resumirPlan(
          plan: _plan(id: 2),
          detalles: [_bolsillo(id: 2, monto: 20000, categoria: 'salud')],
          movimientos: const [],
        ),
      ]);
      expect(reparto, hasLength(1));
      expect(reparto.first.categoria, 'salud');
    });

    test('puede incluir los archivados si se pide', () {
      final reparto = AsignacionLogic.repartoPorCategoria(
        [
          AsignacionLogic.resumirPlan(
            plan: _plan(id: 1, archivado: true),
            detalles: [_bolsillo(id: 1, monto: 30000)],
            movimientos: const [],
          ),
        ],
        incluirArchivados: true,
      );
      expect(reparto, hasLength(1));
      expect(reparto.first.asignado, 30000);
    });
  });

  group('resolverVinculoAutomatico', () {
    test('con una coincidencia única devuelve ese bolsillo', () {
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'alimentacion',
        activoId: 1,
        planes: [_plan(id: 1, activoId: 1)],
        detalles: [
          _bolsillo(id: 11, planId: 1, categoria: 'alimentacion'),
          _bolsillo(id: 12, planId: 1, categoria: 'transporte'),
        ],
      );
      expect(id, 11);
    });

    test('sin coincidencias devuelve null en vez de adivinar', () {
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'salud',
        activoId: 1,
        planes: [_plan(id: 1)],
        detalles: [_bolsillo(id: 11, planId: 1, categoria: 'alimentacion')],
      );
      expect(id, isNull);
    });

    test('dos bolsillos con la misma categoría no se desempatan', () {
      // Si hay dos planes con "alimentacion" elegir uno sería adivinar; el
      // usuario decide desde el formulario.
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'alimentacion',
        activoId: 1,
        planes: [
          _plan(id: 1, activoId: 1, nombre: 'Quincena'),
          _plan(id: 2, activoId: 1, nombre: 'Viaje'),
        ],
        detalles: [
          _bolsillo(id: 11, planId: 1),
          _bolsillo(id: 21, planId: 2),
        ],
      );
      expect(id, isNull);
    });

    test('un plan proyectado no recibe gastos', () {
      // Su dinero todavía no existe: imputarle un gasto mentiría el plan.
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'alimentacion',
        activoId: 1,
        planes: [_plan(id: 1, esProyectado: true)],
        detalles: [_bolsillo(id: 11, planId: 1)],
      );
      expect(id, isNull);
    });

    test('un plan archivado tampoco recibe gastos', () {
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'alimentacion',
        activoId: 1,
        planes: [_plan(id: 1, archivado: true)],
        detalles: [_bolsillo(id: 11, planId: 1)],
      );
      expect(id, isNull);
    });

    test('el bolsillo de otra cuenta no coincide', () {
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'alimentacion',
        activoId: 2,
        planes: [_plan(id: 1, activoId: 1)],
        detalles: [_bolsillo(id: 11, planId: 1)],
      );
      expect(id, isNull);
    });

    test('con la cuenta sin elegir cualquier plan sirve', () {
      final id = AsignacionLogic.resolverVinculoAutomatico(
        categoria: 'alimentacion',
        activoId: null,
        planes: [_plan(id: 1, activoId: 9)],
        detalles: [_bolsillo(id: 11, planId: 1)],
      );
      expect(id, 11);
    });
  });

  group('saldoComprometido', () {
    test('suma lo asignado de los planes reales y activos', () {
      final comprometido = AsignacionLogic.saldoComprometido(
        activoId: 1,
        planes: [_plan(id: 1, activoId: 1)],
        detalles: [
          _bolsillo(id: 11, planId: 1, monto: 60000),
          _bolsillo(id: 12, planId: 1, categoria: 'transporte', monto: 40000),
        ],
      );
      expect(comprometido, 100000);
    });

    test('los planes proyectados no comprometen nada', () {
      final comprometido = AsignacionLogic.saldoComprometido(
        activoId: 1,
        planes: [_plan(id: 1, esProyectado: true)],
        detalles: [_bolsillo(id: 11, planId: 1, monto: 60000)],
      );
      expect(comprometido, 0);
    });

    test('los planes archivados dejan de comprometer', () {
      final comprometido = AsignacionLogic.saldoComprometido(
        activoId: 1,
        planes: [_plan(id: 1, archivado: true)],
        detalles: [_bolsillo(id: 11, planId: 1, monto: 60000)],
      );
      expect(comprometido, 0);
    });

    test('los bolsillos de otra cuenta no cuentan', () {
      final comprometido = AsignacionLogic.saldoComprometido(
        activoId: 2,
        planes: [_plan(id: 1, activoId: 1)],
        detalles: [_bolsillo(id: 11, planId: 1, monto: 60000)],
      );
      expect(comprometido, 0);
    });
  });

  group('saldosDeActivo', () {
    test('libre es el saldo real menos lo comprometido', () {
      final saldos = AsignacionLogic.saldosDeActivo(
        saldoReal: 250000,
        activoId: 1,
        planes: [_plan(id: 1, activoId: 1)],
        detalles: [_bolsillo(id: 11, planId: 1, monto: 100000)],
      );
      expect(saldos.saldoReal, 250000);
      expect(saldos.comprometido, 100000);
      expect(saldos.libre, 150000);
    });

    test('puede quedar negativo si se comprometió de más', () {
      // Se asignó más de lo que hay: la cuenta queda "en rojo" respecto a sus
      // planes, y eso se tiene que ver en vez de recortarse en silencio.
      final saldos = AsignacionLogic.saldosDeActivo(
        saldoReal: 50000,
        activoId: 1,
        planes: [_plan(id: 1, activoId: 1)],
        detalles: [_bolsillo(id: 11, planId: 1, monto: 100000)],
      );
      expect(saldos.libre, -50000);
    });
  });

  group('bolsillosCandidatos', () {
    test('ofrece los bolsillos de la misma cuenta y categoría', () {
      final candidatos = AsignacionLogic.bolsillosCandidatos(
        categoria: 'alimentacion',
        activoId: 1,
        resumenes: _resumenes(
          plan: _plan(id: 1, activoId: 1),
          detalles: [
            _bolsillo(id: 11, planId: 1, categoria: 'alimentacion'),
            _bolsillo(id: 12, planId: 1, categoria: 'transporte'),
          ],
        ),
      );

      expect(candidatos.map((c) => c.detalle.id), [11]);
      expect(candidatos.single.categoria, 'alimentacion');
    });

    test('deja fuera los planes proyectados y archivados', () {
      final candidatos = AsignacionLogic.bolsillosCandidatos(
        categoria: 'alimentacion',
        activoId: 1,
        resumenes: [
          ..._resumenes(
            plan: _plan(id: 1, activoId: 1, esProyectado: true),
            detalles: [_bolsillo(id: 11, planId: 1)],
          ),
          ..._resumenes(
            plan: _plan(id: 2, activoId: 1, archivado: true),
            detalles: [_bolsillo(id: 21, planId: 2)],
          ),
          ..._resumenes(
            plan: _plan(id: 3, activoId: 1),
            detalles: [_bolsillo(id: 31, planId: 3)],
          ),
        ],
      );

      expect(candidatos.map((c) => c.detalle.id), [31]);
    });

    test('con la cuenta sin elegir lista los de todas las cuentas', () {
      final candidatos = AsignacionLogic.bolsillosCandidatos(
        categoria: 'alimentacion',
        activoId: null,
        resumenes: [
          ..._resumenes(
            plan: _plan(id: 1, activoId: 1),
            detalles: [_bolsillo(id: 11, planId: 1)],
          ),
          ..._resumenes(
            plan: _plan(id: 2, activoId: 2),
            detalles: [_bolsillo(id: 21, planId: 2)],
          ),
        ],
      );

      expect(candidatos.map((c) => c.detalle.id), [11, 21]);
    });

    test('trae lo que le queda al bolsillo después de lo gastado', () {
      final candidatos = AsignacionLogic.bolsillosCandidatos(
        categoria: 'alimentacion',
        activoId: 1,
        resumenes: _resumenes(
          plan: _plan(id: 1, activoId: 1),
          detalles: [_bolsillo(id: 11, planId: 1, monto: 60000)],
          movimientos: [_movimiento(monto: 20000, planDetalleId: 11)],
        ),
      );

      expect(candidatos.single.gastado, 20000);
      expect(candidatos.single.restante, 40000);
    });

    test('devuelve vacío cuando la categoría no tiene plan', () {
      final candidatos = AsignacionLogic.bolsillosCandidatos(
        categoria: 'salud',
        activoId: 1,
        resumenes: _resumenes(
          plan: _plan(id: 1, activoId: 1),
          detalles: [_bolsillo(id: 11, planId: 1, categoria: 'alimentacion')],
        ),
      );
      expect(candidatos, isEmpty);
    });
  });
}
