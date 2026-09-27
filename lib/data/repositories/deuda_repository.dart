import '../models/debt.dart';
import '../db/db_helper.dart';

class DeudaRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(Debt deuda) async {
    final db = await _dbHelper.database;
    return await db.insert(Debt.tableName, deuda.toMap());
  }

  Future<List<Debt>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Debt.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Debt.fromMap(map)).toList();
  }

  Future<Debt?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Debt.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Debt.fromMap(maps.first);
  }

  Future<int> update(Debt deuda) async {
    final db = await _dbHelper.database;
    return await db.update(
      Debt.tableName,
      deuda.toMap(),
      where: 'id = ?',
      whereArgs: [deuda.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      Debt.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> registrarPago(int id, double monto) async {
    final db = await _dbHelper.database;
    final deuda = await getById(id);
    if (deuda == null) return 0;
    final nuevoPendiente =
        (deuda.montoPendiente - monto).clamp(0.0, double.infinity);
    return await db.update(
      Debt.tableName,
      {'monto_pendiente': nuevoPendiente},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}