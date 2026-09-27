import '../models/quote_item.dart';
import '../db/db_helper.dart';

class ItemCotizacionRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(QuoteItem item) async {
    final db = await _dbHelper.database;
    return await db.insert(QuoteItem.tableName, item.toMap());
  }

  Future<List<QuoteItem>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(QuoteItem.tableName);
    return maps.map((map) => QuoteItem.fromMap(map)).toList();
  }

  Future<QuoteItem?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      QuoteItem.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return QuoteItem.fromMap(maps.first);
  }

  Future<List<QuoteItem>> getByCotizacionId(int cotizacionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      QuoteItem.tableName,
      where: 'cotizacion_id = ?',
      whereArgs: [cotizacionId],
      orderBy: 'id ASC',
    );
    return maps.map((map) => QuoteItem.fromMap(map)).toList();
  }

  Future<int> update(QuoteItem item) async {
    final db = await _dbHelper.database;
    return await db.update(
      QuoteItem.tableName,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      QuoteItem.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}