import '../models/presupuesto_activo.dart';
import '../db/db_helper.dart';

class PresupuestoActivoRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(PresupuestoActivo presupuesto) async {
    final db = await _dbHelper.database;
    return await db.insert(PresupuestoActivo.tableName, presupuesto.toMap());
  }

  Future<List<PresupuestoActivo>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PresupuestoActivo.tableName,
      orderBy: 'anio DESC, mes DESC',
    );
    return maps.map((map) => PresupuestoActivo.fromMap(map)).toList();
  }

  Future<List<PresupuestoActivo>> getByMesAnio(int mes, int anio) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PresupuestoActivo.tableName,
      where: 'mes = ? AND anio = ?',
      whereArgs: [mes, anio],
      orderBy: 'monto_limite DESC',
    );
    return maps.map((map) => PresupuestoActivo.fromMap(map)).toList();
  }

  Future<PresupuestoActivo?> getByActivoYMes(
    int activoId,
    int mes,
    int anio,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PresupuestoActivo.tableName,
      where: 'activo_id = ? AND mes = ? AND anio = ?',
      whereArgs: [activoId, mes, anio],
    );
    if (maps.isEmpty) return null;
    return PresupuestoActivo.fromMap(maps.first);
  }

  Future<int> update(PresupuestoActivo presupuesto) async {
    final db = await _dbHelper.database;
    return await db.update(
      PresupuestoActivo.tableName,
      presupuesto.toMap(),
      where: 'id = ?',
      whereArgs: [presupuesto.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      PresupuestoActivo.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra los presupuestos del activo eliminado. Los movimientos no se tocan:
  /// el historial del dinero sobrevive al activo.
  Future<int> deleteByActivo(int activoId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      PresupuestoActivo.tableName,
      where: 'activo_id = ?',
      whereArgs: [activoId],
    );
  }
}
