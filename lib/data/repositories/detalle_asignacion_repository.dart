import '../models/detalle_asignacion.dart';
import '../db/db_helper.dart';

/// Acceso a los bolsillos (asignaciones por categoría) de los planes.
class DetalleAsignacionRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(DetalleAsignacion detalle) async {
    final db = await _dbHelper.database;
    return await db.insert(DetalleAsignacion.tableName, detalle.toMap());
  }

  /// Inserta varios detalles en una transacción. Se usa al crear o reemplazar
  /// la distribución completa de un plan.
  Future<void> insertVarios(List<DetalleAsignacion> detalles) async {
    if (detalles.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final detalle in detalles) {
        await txn.insert(DetalleAsignacion.tableName, detalle.toMap());
      }
    });
  }

  Future<List<DetalleAsignacion>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DetalleAsignacion.tableName,
      orderBy: 'plan_id ASC, id ASC',
    );
    return maps.map((map) => DetalleAsignacion.fromMap(map)).toList();
  }

  Future<List<DetalleAsignacion>> getByPlan(int planId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DetalleAsignacion.tableName,
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'id ASC',
    );
    return maps.map((map) => DetalleAsignacion.fromMap(map)).toList();
  }

  Future<int> update(DetalleAsignacion detalle) async {
    final db = await _dbHelper.database;
    return await db.update(
      DetalleAsignacion.tableName,
      detalle.toMap(),
      where: 'id = ?',
      whereArgs: [detalle.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      DetalleAsignacion.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reasigna la categoría de todos los bolsillos que la usaban (p. ej. al
  /// borrar una categoría personalizada), para que la asignación no apunte a una
  /// categoría inexistente. Los movimientos vinculados al bolsillo siguen
  /// contando para su `plan_detalle_id`; lo que cambia es la etiqueta del
  /// bolsillo.
  Future<int> actualizarCategoria(String antigua, String nueva) async {
    final db = await _dbHelper.database;
    return await db.update(
      DetalleAsignacion.tableName,
      {'categoria': nueva},
      where: 'categoria = ?',
      whereArgs: [antigua],
    );
  }

  /// Reemplaza todos los bolsillos de un plan por [detalles]. Desvincula los
  /// movimientos de los bolsillos que desaparecen para no dejar referencias
  /// colgando, y hace todo en una sola transacción.
  Future<void> reemplazarDePlan(
    int planId,
    List<DetalleAsignacion> detalles,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE movimientos SET plan_detalle_id = NULL '
        'WHERE plan_detalle_id IN '
        '(SELECT id FROM ${DetalleAsignacion.tableName} WHERE plan_id = ?)',
        [planId],
      );
      await txn.delete(
        DetalleAsignacion.tableName,
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
      for (final detalle in detalles) {
        await txn.insert(
          DetalleAsignacion.tableName,
          detalle.copyWith(planId: planId).toMap(),
        );
      }
    });
  }
}
