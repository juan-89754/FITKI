import '../models/presupuesto_categoria.dart';
import '../db/db_helper.dart';

/// Acceso a los presupuestos por categoría. Cada fila es un límite de un mes
/// para una categoría; el historial de movimientos nunca se toca desde acá.
class PresupuestoCategoriaRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(PresupuestoCategoria presupuesto) async {
    final db = await _dbHelper.database;
    return await db.insert(PresupuestoCategoria.tableName, presupuesto.toMap());
  }

  Future<List<PresupuestoCategoria>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PresupuestoCategoria.tableName,
      orderBy: 'anio DESC, mes DESC, monto_limite DESC',
    );
    return maps.map((map) => PresupuestoCategoria.fromMap(map)).toList();
  }

  Future<List<PresupuestoCategoria>> getByMesAnio(int mes, int anio) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PresupuestoCategoria.tableName,
      where: 'mes = ? AND anio = ?',
      whereArgs: [mes, anio],
      orderBy: 'monto_limite DESC',
    );
    return maps.map((map) => PresupuestoCategoria.fromMap(map)).toList();
  }

  Future<PresupuestoCategoria?> getByCategoriaYMes(
    String categoria,
    int mes,
    int anio,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PresupuestoCategoria.tableName,
      where: 'categoria = ? AND mes = ? AND anio = ?',
      whereArgs: [categoria, mes, anio],
    );
    if (maps.isEmpty) return null;
    return PresupuestoCategoria.fromMap(maps.first);
  }

  Future<int> update(PresupuestoCategoria presupuesto) async {
    final db = await _dbHelper.database;
    return await db.update(
      PresupuestoCategoria.tableName,
      presupuesto.toMap(),
      where: 'id = ?',
      whereArgs: [presupuesto.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      PresupuestoCategoria.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
