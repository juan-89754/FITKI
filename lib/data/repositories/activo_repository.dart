import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../models/asset.dart';
import '../models/gasto_fijo.dart';
import '../models/loan.dart';
import '../models/presupuesto_activo.dart';
import '../models/transaction.dart';
import '../db/db_helper.dart';

class ActivoRepository {
  final DbHelper _dbHelper = DbHelper();

  /// ÚNICO lugar donde se toca `monto_disponible`. Todos los caminos que
  /// mueven dinero (altas, bajas y pagos de gastos fijos) pasan por acá, así
  /// que la invariante "saldo = saldo inicial + suma de movimientos" no
  /// depende de que cada pantalla se acuerde de ajustar el saldo por su cuenta.
  ///
  /// El saldo puede quedar negativo a propósito: una cuenta puede gastarse más
  /// de lo que tiene (una tarjeta, un sobregiro). Floorearlo en cero hacía que
  /// el saldo dejara de cuadrar con la suma de los movimientos, y como el
  /// presupuesto se calcula sumando movimientos, los dos números que ve el
  /// usuario terminaban en contradicción.
  static Future<void> ajustarSaldoEnTransaccion(
    DatabaseExecutor txn, {
    required int activoId,
    required double delta,
  }) async {
    final maps = await txn.query(
      Asset.tableName,
      columns: ['monto_disponible'],
      where: 'id = ?',
      whereArgs: [activoId],
    );
    if (maps.isEmpty) return;
    final saldoActual = (maps.first['monto_disponible'] as num).toDouble();
    await txn.update(
      Asset.tableName,
      {'monto_disponible': saldoActual + delta},
      where: 'id = ?',
      whereArgs: [activoId],
    );
  }

  /// Delta que un movimiento aplica al saldo de su activo: un gasto lo baja,
  /// un ingreso lo sube.
  static double deltaDeMovimiento(String tipo, double monto) {
    return tipo == Transaction.tipoIngreso ? monto : -monto;
  }

  Future<int> insert(Asset asset) async {
    final db = await _dbHelper.database;
    return await db.insert(Asset.tableName, asset.toMap());
  }

  Future<List<Asset>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Asset.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Asset.fromMap(map)).toList();
  }

  Future<Asset?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Asset.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Asset.fromMap(maps.first);
  }

  Future<int> update(Asset asset) async {
    final db = await _dbHelper.database;
    return await db.update(
      Asset.tableName,
      asset.toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  /// Elimina el activo y su presupuesto del mes. Los gastos fijos que lo
  /// respaldaban quedan sin activo en vez de desaparecer: así el usuario
  /// puede reasignarlos a otra cuenta y no pierde la plantilla ni su
  /// historial. Lo mismo con los préstamos a terceros, que quedan sin cuenta
  /// de origen pero conservan todo su historial. Los movimientos no se tocan
  /// (son el historial del dinero).
  ///
  /// Las claves foráneas no están habilitadas en la conexión, así que las
  /// cascadas declaradas en el esquema se aplican aquí a mano.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await txn.delete(
        PresupuestoActivo.tableName,
        where: 'activo_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        GastoFijo.tableName,
        {'activo_id': null},
        where: 'activo_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        Loan.tableName,
        {'activo_id': null},
        where: 'activo_id = ?',
        whereArgs: [id],
      );
      return txn.delete(
        Asset.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}