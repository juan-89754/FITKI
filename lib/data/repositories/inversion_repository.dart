import '../models/investment.dart';
import '../db/db_helper.dart';

class InversionRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(Investment inversion) async {
    final db = await _dbHelper.database;
    return await db.insert(Investment.tableName, inversion.toMap());
  }

  Future<List<Investment>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Investment.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Investment.fromMap(map)).toList();
  }

  Future<Investment?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Investment.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Investment.fromMap(maps.first);
  }

  Future<int> update(Investment inversion) async {
    final db = await _dbHelper.database;
    return await db.update(
      Investment.tableName,
      inversion.toMap(),
      where: 'id = ?',
      whereArgs: [inversion.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      Investment.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Registra (o actualiza) la ganancia real obtenida de una inversión.
  /// Solo toca la columna de ganancia; el resto del registro no cambia.
  Future<int> registrarGanancia(int id, double ganancia) async {
    final db = await _dbHelper.database;
    return await db.update(
      Investment.tableName,
      {'ganancia_obtenida': ganancia},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}