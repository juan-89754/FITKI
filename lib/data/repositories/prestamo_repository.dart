import '../models/loan.dart';
import '../db/db_helper.dart';

class PrestamoRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(Loan prestamo) async {
    final db = await _dbHelper.database;
    return await db.insert(Loan.tableName, prestamo.toMap());
  }

  Future<List<Loan>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Loan.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Loan.fromMap(map)).toList();
  }

  Future<Loan?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Loan.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Loan.fromMap(maps.first);
  }

  Future<int> update(Loan prestamo) async {
    final db = await _dbHelper.database;
    return await db.update(
      Loan.tableName,
      prestamo.toMap(),
      where: 'id = ?',
      whereArgs: [prestamo.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      Loan.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Registra un pago parcial de un préstamo.
  ///
  /// Mantiene la misma estrategia que los pagos de deuda: se persiste un
  /// acumulado (monto_pagado) clampeado para que nunca supere el monto
  /// prestado, y se deriva el estado con la misma fórmula que expone
  /// `PrestamosLogic.estadoPrestamo` (duplicada aquí para que la BD quede
  /// coherente sin depender de capa de presentación).
  Future<int> registrarPago(int id, double monto) async {
    final db = await _dbHelper.database;
    final prestamo = await getById(id);
    if (prestamo == null) return 0;
    final montoPagado = (prestamo.montoPagado + monto)
        .clamp(0.0, prestamo.montoPrestado);
    return await db.update(
      Loan.tableName,
      {
        'monto_pagado': montoPagado,
        'estado': _derivarEstado(prestamo.montoPrestado, montoPagado),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// derive del estado: pagado_total si el acumulado alcanza (o supera por
  /// redondeo) el monto prestado; pagado_parcial si hay pagos parciales.
  static String _derivarEstado(double montoPrestado, double montoPagado) {
    const epsilon = 0.009;
    if (montoPagado + epsilon >= montoPrestado) return 'pagado_total';
    if (montoPagado > 0) return 'pagado_parcial';
    return 'pendiente';
  }
}