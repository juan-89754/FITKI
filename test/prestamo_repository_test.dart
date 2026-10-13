import 'package:fitki/data/db/db_helper.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/loan.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/repositories/activo_repository.dart';
import 'package:fitki/data/repositories/prestamo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

/// Tests de [PrestamoRepository] sobre una base SQLite real en memoria.
///
/// La regla que estos tests protegen: **un préstamo mueve el dinero de verdad**.
/// Prestar resta de la cuenta de origen y cada reembolso vuelve a ella (o a la
/// que el usuario elija), así que editar un préstamo tiene que recalcular el
/// saldo sin perder lo que ya se había reembolsado.
Loan _prestamo({
  int? id,
  int activoId = 1,
  double monto = 300,
  double montoPagado = 0,
  String estado = 'pendiente',
}) {
  final momento = DateTime(2026, 4, 1);
  return Loan(
    id: id,
    nombreBeneficiario: 'Ana',
    montoPrestado: monto,
    montoPagado: montoPagado,
    activoId: activoId,
    fechaPrestamo: momento,
    fechaPagoEsperada: DateTime(2026, 5, 1),
    fechaCreacion: momento,
    estado: estado,
  );
}

void main() {
  late PrestamoRepository repo;
  late ActivoRepository activosRepo;
  late DbHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Base aislada por archivo de test: evita que varios tests que comparten
    // el mismo `fitki.db` en disco se bloqueen entre sí.
    DbHelper.rutaParaTests = inMemoryDatabasePath;
  });

  setUp(() async {
    dbHelper = DbHelper();
    repo = PrestamoRepository();
    activosRepo = ActivoRepository();
    await dbHelper.database;
    await dbHelper.vaciarDatos();
  });

  tearDownAll(() async {
    await DbHelper().close();
  });

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

  Future<double> saldoDe(int activoId) async {
    final db = await dbHelper.database;
    final filas = await db.query(
      Asset.tableName,
      columns: ['monto_disponible'],
      where: 'id = ?',
      whereArgs: [activoId],
    );
    return (filas.first['monto_disponible'] as num).toDouble();
  }

  Future<List<Map<String, Object?>>> movimientos() async {
    final db = await dbHelper.database;
    return db.query(Transaction.tableName);
  }

  group('actualizarConAjuste', () {
    test('editar sin tocar monto ni cuenta conserva lo reembolsado en el saldo', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_prestamo(activoId: activoId, monto: 300));
      await repo.registrarPago(id, 100);

      expect(await saldoDe(activoId), 800);
      final guardado = await repo.getById(id);
      await repo.actualizarConAjuste(
        original: guardado!,
        nuevo: _prestamo(
          id: id,
          activoId: activoId,
          monto: 300,
          montoPagado: guardado.montoPagado,
          estado: guardado.estado,
        ).copyWith(condiciones: 'sin interés'),
      );

      // Revertir + reaplicar no debe evaporar el reembolso: 1000 - 300 + 100.
      expect(await saldoDe(activoId), 800);
      final movs = await movimientos();
      expect(movs, hasLength(2), reason: 'salida y reembolso siguen en el historial');
      expect(
        movs.any((m) =>
            m['tipo'] == Transaction.tipoIngreso &&
            (m['monto'] as num).toDouble() == 100),
        isTrue,
        reason: 'el reembolso sobrevive a la edición',
      );
    });

    test('mover el préstamo a otra cuenta lleva los reembolsos con él', () async {
      final activoA = await crearActivo(1000, nombre: 'A');
      final activoB = await crearActivo(500, nombre: 'B');
      final id = await repo.insert(_prestamo(activoId: activoA, monto: 300));
      await repo.registrarPago(id, 100);

      final guardado = await repo.getById(id);
      await repo.actualizarConAjuste(
        original: guardado!,
        nuevo: _prestamo(
          id: id,
          activoId: activoB,
          monto: 300,
          montoPagado: guardado.montoPagado,
          estado: guardado.estado,
        ),
      );

      // A queda con su saldo original y B asume salida y reembolso: 500 - 300 + 100.
      expect(await saldoDe(activoA), 1000);
      expect(await saldoDe(activoB), 300);
      expect((await repo.getById(id))!.activoId, activoB);

      final movs = await movimientos();
      expect(movs, hasLength(2));
      expect(
        movs.every((m) => m['activo_id'] == activoB),
        isTrue,
        reason: 'ambos movimientos apuntan a la cuenta nueva',
      );
    });

    test('bajar el monto prestado arriba de lo reembolsado se rechaza', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_prestamo(activoId: activoId, monto: 300));
      await repo.registrarPago(id, 200);

      final guardado = await repo.getById(id);
      await expectLater(
        repo.actualizarConAjuste(
          original: guardado!,
          nuevo: _prestamo(
            id: id,
            activoId: activoId,
            monto: 100,
            montoPagado: guardado.montoPagado,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'mensaje',
            contains('no puede ser menor a lo ya reembolsado'),
          ),
        ),
      );
      // El rechazo no dejó el saldo tocado.
      expect(await saldoDe(activoId), 900);
    });

    test('delete revierte la salida y los reembolsos, y borra el historial', () async {
      final activoId = await crearActivo(1000);
      final id = await repo.insert(_prestamo(activoId: activoId, monto: 300));
      await repo.registrarPago(id, 100);

      await repo.delete(id);

      expect(await repo.getAll(), isEmpty);
      expect(await movimientos(), isEmpty,
          reason: 'ni la salida ni el reembolso quedan huérfanos');
      expect(await saldoDe(activoId), 1000,
          reason: 'eliminar el préstamo devuelve todo el dinero al activo');
    });
  });
}