import '../models/quote_project.dart';
import '../db/db_helper.dart';

class ProyectoRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(QuoteProject proyecto) async {
    final db = await _dbHelper.database;
    return await db.insert(QuoteProject.tableName, proyecto.toMap());
  }

  Future<List<QuoteProject>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      QuoteProject.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => QuoteProject.fromMap(map)).toList();
  }

  Future<QuoteProject?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      QuoteProject.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return QuoteProject.fromMap(maps.first);
  }

  Future<int> update(QuoteProject proyecto) async {
    final db = await _dbHelper.database;
    return await db.update(
      QuoteProject.tableName,
      proyecto.toMap(),
      where: 'id = ?',
      whereArgs: [proyecto.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      QuoteProject.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}