import '../models/perfil.dart';
import '../db/db_helper.dart';

class PerfilRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(Perfil perfil) async {
    final db = await _dbHelper.database;
    return await db.insert(Perfil.tableName, perfil.toMap());
  }

  Future<List<Perfil>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(Perfil.tableName);
    return maps.map((map) => Perfil.fromMap(map)).toList();
  }

  /// Devuelve el perfil del usuario (hay un único registro) o null si aún
  /// no se ha creado.
  Future<Perfil?> obtenerUno() async {
    final perfiles = await getAll();
    if (perfiles.isEmpty) return null;
    return perfiles.first;
  }

  Future<Perfil?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Perfil.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Perfil.fromMap(maps.first);
  }

  Future<int> update(Perfil perfil) async {
    final db = await _dbHelper.database;
    return await db.update(
      Perfil.tableName,
      perfil.toMap(),
      where: 'id = ?',
      whereArgs: [perfil.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      Perfil.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}