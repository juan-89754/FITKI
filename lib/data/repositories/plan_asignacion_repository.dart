import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../models/detalle_asignacion.dart';
import '../models/plan_asignacion.dart';
import '../db/db_helper.dart';

/// Acceso a los planes de asignación y sus bolsillos.
///
/// Reemplazan al presupuesto mensual: no hay período, el plan se archiva a mano.
/// El dinero gastado nunca se guarda acá; se deriva de los movimientos.
class PlanAsignacionRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(PlanAsignacion plan) async {
    final db = await _dbHelper.database;
    return await db.insert(PlanAsignacion.tableName, plan.toMap());
  }

  Future<List<PlanAsignacion>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PlanAsignacion.tableName,
      orderBy: 'archivado ASC, fecha_creacion DESC',
    );
    return maps.map((map) => PlanAsignacion.fromMap(map)).toList();
  }

  Future<List<PlanAsignacion>> getByActivo(int activoId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PlanAsignacion.tableName,
      where: 'activo_id = ?',
      whereArgs: [activoId],
      orderBy: 'archivado ASC, fecha_creacion DESC',
    );
    return maps.map((map) => PlanAsignacion.fromMap(map)).toList();
  }

  Future<PlanAsignacion?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PlanAsignacion.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return PlanAsignacion.fromMap(maps.first);
  }

  Future<int> update(PlanAsignacion plan) async {
    final db = await _dbHelper.database;
    return await db.update(
      PlanAsignacion.tableName,
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  /// Archiva (liquida) el plan: deja de contar para el saldo comprometido pero
  /// conserva su historial y sus bolsillos.
  Future<int> archivar(int id, DateTime fechaCierre) async {
    final db = await _dbHelper.database;
    return await db.update(
      PlanAsignacion.tableName,
      {
        'archivado': 1,
        'fecha_cierre': fechaCierre.toIso8601String().split('T').first,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra el plan y, en la misma transacción, sus bolsillos. Las claves
  /// foráneas no están habilitadas, así que la cascada se hace a mano. Los
  /// movimientos no se tocan: su `plan_detalle_id` apuntaría a un bolsillo
  /// inexistente, así que primero se desvinculan.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _desvincularMovimientos(txn, id);
      await txn.delete(
        DetalleAsignacion.tableName,
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      return txn.delete(
        PlanAsignacion.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> _desvincularMovimientos(DatabaseExecutor txn, int planId) async {
    await txn.rawUpdate(
      'UPDATE movimientos SET plan_detalle_id = NULL '
      'WHERE plan_detalle_id IN '
      '(SELECT id FROM ${DetalleAsignacion.tableName} WHERE plan_id = ?)',
      [planId],
    );
  }
}
