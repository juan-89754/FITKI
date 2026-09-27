import '../models/categoria_personalizada.dart';
import '../db/db_helper.dart';

class CategoriaPersonalizadaRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(CategoriaPersonalizada categoria) async {
    final db = await _dbHelper.database;
    return await db.insert(CategoriaPersonalizada.tableName, categoria.toMap());
  }

  Future<List<CategoriaPersonalizada>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      CategoriaPersonalizada.tableName,
      orderBy: 'nombre ASC',
    );
    return maps.map((map) => CategoriaPersonalizada.fromMap(map)).toList();
  }

  /// Categorías que deben aparecer en el dropdown correspondiente: 'gasto'
  /// o 'ingreso'.
  Future<List<CategoriaPersonalizada>> getByTipo(String tipo) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      CategoriaPersonalizada.tableName,
      where: 'tipo = ?',
      whereArgs: [tipo],
      orderBy: 'nombre ASC',
    );
    return maps.map((map) => CategoriaPersonalizada.fromMap(map)).toList();
  }

  Future<CategoriaPersonalizada?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      CategoriaPersonalizada.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CategoriaPersonalizada.fromMap(maps.first);
  }

  Future<int> update(CategoriaPersonalizada categoria) async {
    final db = await _dbHelper.database;
    return await db.update(
      CategoriaPersonalizada.tableName,
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      CategoriaPersonalizada.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}