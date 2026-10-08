import 'package:fitki/data/db/db_helper.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/investment.dart';
import 'package:fitki/data/models/inversion_movimiento.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/repositories/activo_repository.dart';
import 'package:fitki/data/repositories/inversion_repository.dart';
import 'package:fitki/logic/categorias/categoria_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

/// Tests de [InversionRepository] sobre una base SQLite real en memoria.
///
/// La regla que estos tests protegen es la misma de las metas: **aportar a una
/// inversión no mueve el Saldo Total de la cuenta**, solo lo pasa de
/// "disponible" a "reservado". El capital y el resultado se derivan del
/// historial de `inversiones_movimientos`, y solo al finalizar el resultado
/// neto se registra una vez como movimiento real (ingreso si ganó, gasto si
/// perdió), que es lo único que ajusta `activos.monto_disponible`.
///
/// Se usa `sqflite_common_ffi` para que [DbHelper] hable con una base de verdad
/// sin depender del canal nativo de Flutter.
Investment _inversion({
  int activoId = 1,
  double monto = 300,
  String tipo = 'bolsa',
  String estado = Investment.estadoActiva,
  DateTime? fecha,
}) {
  final momento = fecha ?? DateTime(2026, 4, 1);
  return Investment(
    tipo: tipo,
    activoId: activoId,
    montoInvertido: monto,
    fecha: momento,
    estado: estado,
    fechaCreacion: momento,
  );
}

void main() {
  late InversionRepository repo;
  late ActivoRepository activosRepo;
  late DbHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DbHelper();
    repo = InversionRepository();
    activosRepo = ActivoRepository();
    await dbHelper.database;
    await dbHelper.vaciarDatos();
  });

  tearDownAll(() async {
    await DbHelper().close();
  });

  /// Crea una cuenta con [saldo] y devuelve su id.
  Future<int> crearActivo(double saldo, {String nombre = 'Banco'}) {
    return activosRepo.insert(
      Asset(
        nombre: nombre,
        tipo: 'cuenta_bancaria',
        montoDisponible: saldo,
        moneda: 'COP',
        fechaCreacion: DateTime(2026, 1, 1),
      ),
    );
  }

  Future<double> saldoTotalDe(int activoId) async {
    final db = await dbHelper.database;
    final filas = await db.query(
      Asset.tableName,
      columns: ['monto_disponible'],
      where: 'id = ?',
      whereArgs: [activoId],
    );
    return (filas.first['monto_disponible'] as num).toDouble();
  }

  Future<double> disponibleDe(int activoId) async {
    final db = await dbHelper.database;
    return InversionRepository.saldoDisponibleDe(db, activoId);
  }

  Future<List<Map<String, Object?>>> movimientosDeCuenta() async {
    final db = await dbHelper.database;
    return db.query(Transaction.tableName);
  }

  group('insert', () {
    test('reserva el monto inicial y baja el disponible de la cuenta', () async {
      final activoId = await crearActivo(1000);

      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      final guardada = await repo.getById(id);
      expect(guardada!.montoInvertido, 300);
      expect(guardada.estaActiva, isTrue);
      expect(await saldoTotalDe(activoId), 1000, reason: 'el total no se mueve');
      expect(await disponibleDe(activoId), 700, reason: '300 quedan reservados');

      final movimientos = await repo.getMovimientosDe(id);
      expect(movimientos, hasLength(1));
      expect(movimientos.single.tipo, InversionMovimiento.tipoAporte);
      expect(movimientos.single.monto, 300);
      expect(movimientos.single.activoId, activoId);
    });

    test('rechaza un monto no positivo', () async {
      final activoId = await crearActivo(1000);

      await expectLater(
        repo.insert(_inversion(activoId: activoId, monto: 0)),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });

    test('rechaza una inversión sin cuenta de origen', () async {
      await expectLater(
        repo.insert(
          Investment(
            tipo: 'bolsa',
            montoInvertido: 100,
            fecha: DateTime(2026, 4, 1),
            fechaCreacion: DateTime(2026, 4, 1),
          ),
        ),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });

    test('rechaza un monto mayor al disponible', () async {
      final activoId = await crearActivo(100);

      await expectLater(
        repo.insert(_inversion(activoId: activoId, monto: 300)),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });
  });

  group('registrarAporte / registrarRetiro', () {
    test('un aporte sube el capital y baja el disponible', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await repo.registrarAporte(
        inversionId: id,
        monto: 200,
        activoId: activoId,
        fecha: DateTime(2026, 4, 2),
      );

      expect((await repo.getById(id))!.montoInvertido, 500);
      expect(await disponibleDe(activoId), 500);
      expect(await saldoTotalDe(activoId), 1000);
    });

    test('un aporte mayor al disponible se rechaza', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 900));

      await expectLater(
        repo.registrarAporte(
          inversionId: id,
          monto: 200,
          activoId: activoId,
          fecha: DateTime(2026, 4, 2),
        ),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });

    test('un retiro baja el capital y devuelve el disponible', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await repo.registrarRetiro(
        inversionId: id,
        monto: 100,
        activoId: activoId,
        fecha: DateTime(2026, 4, 2),
      );

      expect((await repo.getById(id))!.montoInvertido, 200);
      expect(await disponibleDe(activoId), 800);
    });

    test('un retiro mayor al capital reservado se rechaza', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await expectLater(
        repo.registrarRetiro(
          inversionId: id,
          monto: 400,
          activoId: activoId,
          fecha: DateTime(2026, 4, 2),
        ),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });
  });

  group('registrarGanancia / registrarPerdida', () {
    test('la ganancia suma al resultado sin tocar la cuenta ni el capital', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await repo.registrarGanancia(
        inversionId: id,
        monto: 50,
        fecha: DateTime(2026, 4, 10),
      );

      final guardada = await repo.getById(id);
      expect(guardada!.gananciaObtenida, 50);
      expect(guardada.montoInvertido, 300, reason: 'el capital no cambia');
      expect(await saldoTotalDe(activoId), 1000);
      expect(await disponibleDe(activoId), 700);
      expect(await movimientosDeCuenta(), isEmpty);
    });

    test('la pérdida resta del resultado con signo negativo', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await repo.registrarPerdida(
        inversionId: id,
        monto: 80,
        fecha: DateTime(2026, 4, 10),
      );

      expect((await repo.getById(id))!.gananciaObtenida, -80);
      expect(await disponibleDe(activoId), 700);
    });

    test('rechaza un monto negativo', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await expectLater(
        repo.registrarGanancia(inversionId: id, monto: -1),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });
  });

  group('finalizar', () {
    test('una ganancia neta entra como ingreso y sube el saldo real', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));
      await repo.registrarGanancia(
        inversionId: id,
        monto: 100,
        fecha: DateTime(2026, 4, 10),
      );

      await repo.finalizar(id, fecha: DateTime(2026, 4, 30));

      expect((await repo.getById(id))!.estaActiva, isFalse);
      // El capital reservado (300) se libera y la ganancia (100) entra: 1000 + 100.
      expect(await disponibleDe(activoId), 1100);
      expect(await saldoTotalDe(activoId), 1100);

      final movs = await movimientosDeCuenta();
      expect(movs, hasLength(1));
      expect(movs.single['tipo'], Transaction.tipoIngreso);
      expect(movs.single['categoria'], categoriaGananciaInversion);
      expect((movs.single['monto'] as num).toDouble(), 100);
    });

    test('una pérdida neta sale como gasto y baja el saldo real', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));
      await repo.registrarGanancia(
        inversionId: id,
        monto: 50,
        fecha: DateTime(2026, 4, 10),
      );
      await repo.registrarPerdida(
        inversionId: id,
        monto: 150,
        fecha: DateTime(2026, 4, 11),
      );

      await repo.finalizar(id, fecha: DateTime(2026, 4, 30));

      // Resultado neto -100: 1000 - 100.
      expect(await saldoTotalDe(activoId), 900);
      final movs = await movimientosDeCuenta();
      expect(movs.single['tipo'], Transaction.tipoGasto);
      expect(movs.single['categoria'], categoriaPerdidaInversion);
      expect((movs.single['monto'] as num).toDouble(), 100);
    });

    test('sin resultado no escribe movimiento y solo libera la reserva', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await repo.finalizar(id, fecha: DateTime(2026, 4, 30));

      expect((await repo.getById(id))!.estaActiva, isFalse);
      expect(await disponibleDe(activoId), 1000);
      expect(await movimientosDeCuenta(), isEmpty);
    });

    test('finalizar dos veces se rechaza', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));
      await repo.finalizar(id, fecha: DateTime(2026, 4, 30));

      await expectLater(
        repo.finalizar(id),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });

    test('una inversión finalizada ya no acepta aportes ni resultados', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));
      await repo.finalizar(id, fecha: DateTime(2026, 4, 30));

      await expectLater(
        repo.registrarGanancia(inversionId: id, monto: 10),
        throwsA(isA<OperacionInversionInvalida>()),
      );
    });
  });

  group('delete', () {
    test('borra la inversión y su historial, y libera la reserva', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_inversion(activoId: activoId, monto: 300));

      await repo.delete(id);

      expect(await repo.getAll(), isEmpty);
      expect(await repo.getMovimientosDe(id), isEmpty);
      expect(await disponibleDe(activoId), 1000);
    });
  });

  group('saldoReservadoEnActivo', () {
    test('solo cuenta el capital de inversiones activas de esa cuenta', () async {
      final activo1 = await crearActivo(1000, nombre: 'A');
      final activo2 = await crearActivo(1000, nombre: 'B');
      final db = await dbHelper.database;

      final inv1 = await repo.insert(_inversion(activoId: activo1, monto: 300));
      final inv2 = await repo.insert(_inversion(activoId: activo1, monto: 200));
      await repo.insert(_inversion(activoId: activo2, monto: 100));

      // Finalizar inv2 libera su capital.
      await repo.finalizar(inv2);

      expect(await InversionRepository.saldoReservadoEnActivo(db, activo1), 300);
      expect(await InversionRepository.saldoReservadoEnActivo(db, activo2), 100);
      // inv1 sigue activa.
      expect((await repo.getById(inv1))!.estaActiva, isTrue);
    });
  });
}
