import '../models/quote.dart';
import '../db/db_helper.dart';

class CotizacionRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(Quote cotizacion) async {
    final db = await _dbHelper.database;
    return await db.insert(Quote.tableName, cotizacion.toMap());
  }

  Future<List<Quote>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Quote.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Quote.fromMap(map)).toList();
  }

  Future<Quote?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Quote.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Quote.fromMap(maps.first);
  }

  Future<List<Quote>> getByProyectoId(int proyectoId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Quote.tableName,
      where: 'proyecto_id = ?',
      whereArgs: [proyectoId],
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Quote.fromMap(map)).toList();
  }

  Future<int> update(Quote cotizacion) async {
    final db = await _dbHelper.database;
    return await db.update(
      Quote.tableName,
      cotizacion.toMap(),
      where: 'id = ?',
      whereArgs: [cotizacion.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      Quote.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}