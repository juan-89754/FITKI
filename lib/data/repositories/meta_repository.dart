import '../models/financial_goal.dart';
import '../db/db_helper.dart';

class MetaRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(FinancialGoal meta) async {
    final db = await _dbHelper.database;
    return await db.insert(FinancialGoal.tableName, meta.toMap());
  }

  Future<List<FinancialGoal>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      FinancialGoal.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => FinancialGoal.fromMap(map)).toList();
  }

  Future<FinancialGoal?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      FinancialGoal.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return FinancialGoal.fromMap(maps.first);
  }

  Future<int> update(FinancialGoal meta) async {
    final db = await _dbHelper.database;
    return await db.update(
      FinancialGoal.tableName,
      meta.toMap(),
      where: 'id = ?',
      whereArgs: [meta.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      FinancialGoal.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> agregarAporte(int id, double monto) async {
    final db = await _dbHelper.database;
    final meta = await getById(id);
    if (meta == null) return 0;
    final nuevoAhorrado = (meta.montoAhorrado + monto).clamp(0.0, double.infinity);
    return await db.update(
      FinancialGoal.tableName,
      {'monto_ahorrado': nuevoAhorrado},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}