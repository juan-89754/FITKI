import 'package:intl/intl.dart';
import '../models/pago_gasto_fijo.dart';
import '../models/transaction.dart';
import '../db/db_helper.dart';
import 'activo_repository.dart';

class PagoGastoFijoRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(PagoGastoFijo pago) async {
    final db = await _dbHelper.database;
    return await db.insert(PagoGastoFijo.tableName, pago.toMap());
  }

  /// Inserta varios pagos del mismo mes en una única transacción. Si uno de
  /// ellos ya existe choca con el UNIQUE (gasto_fijo_id, mes, anio) y se
  /// revierte todo: nunca queda medio mes generado.
  Future<void> insertVarios(List<PagoGastoFijo> pagos) async {
    if (pagos.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final pago in pagos) {
        await txn.insert(PagoGastoFijo.tableName, pago.toMap());
      }
    });
  }

  Future<List<PagoGastoFijo>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PagoGastoFijo.tableName,
      orderBy: 'anio DESC, mes DESC, monto_estimado DESC',
    );
    return maps.map((map) => PagoGastoFijo.fromMap(map)).toList();
  }

  Future<List<PagoGastoFijo>> getByMesAnio(int mes, int anio) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PagoGastoFijo.tableName,
      where: 'mes = ? AND anio = ?',
      whereArgs: [mes, anio],
      orderBy: 'monto_estimado DESC',
    );
    return maps.map((map) => PagoGastoFijo.fromMap(map)).toList();
  }

  /// Pagos ya confirmados de una plantilla, del más reciente al más antiguo.
  /// Es la fuente del promedio con el que se precarga el monto de los gastos
  /// de precio variable.
  Future<List<PagoGastoFijo>> getPagadosByGastoFijo(
    int gastoFijoId, {
    int limite = 6,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      PagoGastoFijo.tableName,
      where: 'gasto_fijo_id = ? AND monto_pagado IS NOT NULL',
      whereArgs: [gastoFijoId],
      orderBy: 'anio DESC, mes DESC',
      limit: limite,
    );
    return maps.map((map) => PagoGastoFijo.fromMap(map)).toList();
  }

  /// Registra el pago y, en la misma transacción, el movimiento de dinero que
  /// lo representa junto con el ajuste del saldo del activo. O queda todo
  /// escrito o no queda nada: nunca hay un pago marcado sin su movimiento ni
  /// un saldo descontado sin pago.
  Future<int> registrarPagoConMovimiento({
    required PagoGastoFijo pago,
    required String categoria,
    required double monto,
    required int activoId,
    required DateTime fechaPago,
    String? nota,
  }) async {
    final db = await _dbHelper.database;
    final movimiento = Transaction(
      tipo: Transaction.tipoGasto,
      monto: monto,
      categoria: categoria,
      fecha: fechaPago,
      activoId: activoId,
      nota: nota,
      fechaCreacion: DateTime.now(),
    );

    return db.transaction<int>((txn) async {
      // El mapa lo arma el propio modelo, así las fechas se guardan en el
      // formato que Transaction.fromMap sabe leer.
      final movimientoId =
          await txn.insert(Transaction.tableName, movimiento.toMap());

      // El ajuste del saldo lo aplica el dueño de la operación
      // (ActivoRepository), igual que en cualquier alta o baja de movimiento.
      await ActivoRepository.ajustarSaldoEnTransaccion(
        txn,
        activoId: activoId,
        delta: ActivoRepository.deltaDeMovimiento(movimiento.tipo, movimiento.monto),
      );

      await txn.update(
        PagoGastoFijo.tableName,
        {
          'monto_pagado': movimiento.monto,
          'fecha_pago': DateFormat('yyyy-MM-dd').format(movimiento.fecha),
          'movimiento_id': movimientoId,
        },
        where: 'id = ?',
        whereArgs: [pago.id],
      );

      return movimientoId;
    });
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      PagoGastoFijo.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
