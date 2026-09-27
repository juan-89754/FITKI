import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/transaction.dart';
import '../db/db_helper.dart';
import 'activo_repository.dart';

class MovimientoRepository {
  final DbHelper _dbHelper = DbHelper();

  /// Guarda el movimiento y descuenta/suma el saldo de su activo en la misma
  /// transacción. El ajuste vive acá y no en la pantalla que llama: así ningún
  /// camino puede olvidarse de hacerlo y el saldo nunca queda descuadrado con
  /// su propio historial.
  Future<int> insert(Transaction movimiento) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert(Transaction.tableName, movimiento.toMap());
      final activoId = movimiento.activoId;
      if (activoId != null) {
        await ActivoRepository.ajustarSaldoEnTransaccion(
          txn,
          activoId: activoId,
          delta: ActivoRepository.deltaDeMovimiento(
            movimiento.tipo,
            movimiento.monto,
          ),
        );
      }
      return id;
    });
  }

  Future<List<Transaction>> getAll({String? tipo}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Transaction.tableName,
      where: tipo != null ? 'tipo = ?' : null,
      whereArgs: tipo != null ? [tipo] : null,
      orderBy: 'fecha DESC, fecha_creacion DESC',
    );
    return maps.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<Transaction?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Transaction.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Transaction.fromMap(maps.first);
  }

  Future<int> update(Transaction movimiento) async {
    final db = await _dbHelper.database;
    return await db.update(
      Transaction.tableName,
      movimiento.toMap(),
      where: 'id = ?',
      whereArgs: [movimiento.id],
    );
  }

  /// Actualiza un movimiento y ajusta los saldos de los activos afectados en
  /// una única transacción: revierte el efecto del movimiento original sobre
  /// su activo (si tenía), aplica el efecto del movimiento nuevo (si tiene
  /// activo) y actualiza la fila del movimiento. Si cualquiera de las
  /// operaciones falla, la transacción se revierte y no queda ninguna
  /// escritura aplicada: el saldo nunca queda inconsistente con el
  /// movimiento guardado.
  Future<void> actualizarConAjusteDeSaldo({
    required Transaction original,
    required Transaction nuevo,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (original.activoId != null) {
        await _ajustarSaldo(
          txn,
          activoId: original.activoId!,
          monto: original.monto,
          tipo: original.tipo,
          revirtiendo: true,
        );
      }
      if (nuevo.activoId != null) {
        await _ajustarSaldo(
          txn,
          activoId: nuevo.activoId!,
          monto: nuevo.monto,
          tipo: nuevo.tipo,
          revirtiendo: false,
        );
      }
      await txn.update(
        Transaction.tableName,
        nuevo.toMap(),
        where: 'id = ?',
        whereArgs: [nuevo.id],
      );
    });
  }

  Future<void> _ajustarSaldo(
    DatabaseExecutor txn, {
    required int activoId,
    required double monto,
    required String tipo,
    required bool revirtiendo,
  }) async {
    final signo = ActivoRepository.deltaDeMovimiento(tipo, monto);
    await ActivoRepository.ajustarSaldoEnTransaccion(
      txn,
      activoId: activoId,
      // Revertir un movimiento es aplicar exactamente el mismo cambio con el
      // signo contrario.
      delta: revirtiendo ? -signo : signo,
    );
  }

  /// Borra el movimiento y devuelve su monto al saldo del activo que había
  /// tocado, en la misma transacción. Borrar sin devolver el dinero dejaba el
  /// activo descuadrado para siempre.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final maps = await txn.query(
        Transaction.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return 0;
      final movimiento = Transaction.fromMap(maps.first);
      final activoId = movimiento.activoId;
      if (activoId != null) {
        await _ajustarSaldo(
          txn,
          activoId: activoId,
          monto: movimiento.monto,
          tipo: movimiento.tipo,
          revirtiendo: true,
        );
      }
      return txn.delete(
        Transaction.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Reasigna la categoría de todos los movimientos que la usaban (p. ej. al
  /// borrar una categoría personalizada), para que el historial siga legible
  /// y no apunte a una categoría inexistente.
  Future<int> actualizarCategoria(String antigua, String nueva) async {
    final db = await _dbHelper.database;
    return await db.update(
      Transaction.tableName,
      {'categoria': nueva},
      where: 'categoria = ?',
      whereArgs: [antigua],
    );
  }

  Future<List<Transaction>> getByRangoFechas(
    DateTime inicio,
    DateTime fin, {
    String? tipo,
  }) async {
    final db = await _dbHelper.database;
    final inicioStr = DateFormat('yyyy-MM-dd').format(inicio);
    final finStr = DateFormat('yyyy-MM-dd').format(fin);

    var where = 'fecha >= ? AND fecha <= ?';
    final args = <dynamic>[inicioStr, finStr];
    if (tipo != null) {
      where += ' AND tipo = ?';
      args.add(tipo);
    }

    final maps = await db.query(
      Transaction.tableName,
      where: where,
      whereArgs: args,
      orderBy: 'fecha DESC, fecha_creacion DESC',
    );
    return maps.map((map) => Transaction.fromMap(map)).toList();
  }
}