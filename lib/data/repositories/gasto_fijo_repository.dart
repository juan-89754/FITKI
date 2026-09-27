import '../models/gasto_fijo.dart';
import '../db/db_helper.dart';

class GastoFijoRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(GastoFijo gasto) async {
    final db = await _dbHelper.database;
    return await db.insert(GastoFijo.tableName, gasto.toMap());
  }

  Future<List<GastoFijo>> getAll({bool soloHabilitados = false}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      GastoFijo.tableName,
      where: soloHabilitados ? 'habilitado = 1' : null,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return maps.map((map) => GastoFijo.fromMap(map)).toList();
  }

  Future<GastoFijo?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      GastoFijo.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return GastoFijo.fromMap(maps.first);
  }

  Future<int> update(GastoFijo gasto) async {
    final db = await _dbHelper.database;
    return await db.update(
      GastoFijo.tableName,
      gasto.toMap(),
      where: 'id = ?',
      whereArgs: [gasto.id],
    );
  }

  /// Elimina solo la plantilla. Los pagos ya confirmados NO se borran: se
  /// quedan como registro y el dinero ya movido sigue en `movimientos`, que es
  /// el historial real. Lo normal para dejar de pagar algo es pausar la
  /// plantilla, que sí conserva la trazabilidad.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      GastoFijo.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reasigna las plantillas de una categoría antes de borrarla, para que
  /// ninguna quede apuntando a una categoría que ya no existe.
  Future<int> actualizarCategoria(String actual, String nueva) async {
    final db = await _dbHelper.database;
    return await db.update(
      GastoFijo.tableName,
      {'categoria': nueva},
      where: 'categoria = ?',
      whereArgs: [actual],
    );
  }

  /// Suelta la plantilla cuando se elimina el activo que la respaldaba. Deja
  /// la plantilla viva (el usuario puede reasignarle otra cuenta) pero sin
  /// activo, que es el estado en que la pantalla de pago vuelve a exigir
  /// elegir uno.
  Future<int> desvincularActivo(int activoId) async {
    final db = await _dbHelper.database;
    return await db.update(
      GastoFijo.tableName,
      {'activo_id': null},
      where: 'activo_id = ?',
      whereArgs: [activoId],
    );
  }
}
