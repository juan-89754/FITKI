import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/loan.dart';
import '../models/transaction.dart';
import '../db/db_helper.dart';
import 'activo_repository.dart';

/// Alta, edición, baja y pagos de un préstamo a terceros, siempre conectados al
/// activo del que salió el dinero.
///
/// La regla que sostiene el módulo es la misma del resto de la app: el dinero
/// que se presta **sale** de la cuenta del usuario y lo que el beneficiario
/// reembolsa **vuelve** a esa misma cuenta. Por eso cada operación escribe tres
/// cosas juntas —el préstamo, sus movimientos y el saldo del activo— dentro de
/// una única transacción. Si alguna falla, no queda ninguna aplicada: un
/// préstamo nunca puede existir con un saldo que ya no le corresponde.
class PrestamoRepository {
  final DbHelper _dbHelper = DbHelper();

  Future<int> insert(Loan prestamo) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert(Loan.tableName, prestamo.toMap());
      await _escribirMovimientoDeSalida(
        txn,
        prestamo,
        monto: prestamo.montoPrestado,
        activoId: prestamo.activoId,
      );
      return id;
    });
  }

  Future<List<Loan>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Loan.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Loan.fromMap(map)).toList();
  }

  Future<Loan?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Loan.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Loan.fromMap(maps.first);
  }

  /// Actualiza el préstamo y recalcula el impacto en el activo.
  ///
  /// Reescribe los movimientos del préstamo (salida y reembolsos) para que
  /// reflejen exactamente los datos nuevos: primero se revierte el efecto del
  /// préstamo original sobre su activo, después se aplica el del nuevo. Así
  /// cambiar el monto o mover el préstamo a otra cuenta deja el saldo
  /// recalculado en lugar de acumulado.
  ///
  /// Falla si el monto nuevo queda por debajo de lo ya reembolsado: ese estado
  /// no tiene representación posible y aceptarlo dejaría el préstamo con más
  /// reembolsos que el monto prestado.
  Future<void> actualizarConAjuste({
    required Loan original,
    required Loan nuevo,
  }) async {
    final id = original.id;
    if (id == null) throw Exception('El préstamo no tiene id');
    if (nuevo.montoPrestado + 0.009 < nuevo.montoPagado) {
      throw Exception('El monto no puede ser menor a lo ya reembolsado');
    }

    final db = await _dbHelper.database;
    await db.transaction<void>((txn) async {
      // 0. Los reembolsos se leen ANTES de revertir: son el historial que hay
      //    que preservar al reescribir los movimientos del préstamo.
      final reembolsos = await _reembolsosRegistrados(txn, id);

      // 1. Se deshace por completo lo que el préstamo original le hizo al
      //    activo y a sus movimientos.
      await _revertirMovimientos(txn, id);

      // 2. Se aplican los datos nuevos: la fila del préstamo y el movimiento
      //    de salida, con el monto y la cuenta que ahora rigen.
      await txn.update(
        Loan.tableName,
        nuevo.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await _escribirMovimientoDeSalida(
        txn,
        nuevo,
        monto: nuevo.montoPrestado,
        activoId: nuevo.activoId,
      );

      // 3. Los reembolsos que ya existían se vuelven a escribir apuntando a la
      //    cuenta nueva. No se recalculan porque el usuario no los está
      //    editando: se preservan con su fecha y su nota, que es lo que espera
      //    al ver su historial.
      for (final reembolso in reembolsos) {
        await txn.insert(Transaction.tableName, {
          'tipo': Transaction.tipoIngreso,
          'monto': reembolso.monto,
          'categoria': Loan.categoriaReembolso,
          'fecha': _fechaDe(reembolso),
          'activo_id': nuevo.activoId,
          'prestamo_id': id,
          'nota': reembolso.nota,
          'fecha_creacion': _fechaCreacionDe(reembolso),
        });
      }
    });
  }

  /// Elimina el préstamo y todo lo que generó, devolviendo el dinero al activo.
  ///
  /// Se borran sus movimientos y se revierte su efecto sobre el saldo antes de
  /// quitar la fila: si el préstamo desapareciera sin más, el monto prestado
  /// seguiría descontado de la cuenta y lo reembolsado seguiría sumándole, sin
  /// ninguna forma de corregirlo.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _revertirMovimientos(txn, id);
      return txn.delete(
        Loan.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Registra un pago (reembolso) del beneficio: el monto vuelve al activo del
  /// préstamo como un ingreso y el acumulado se actualiza.
  ///
  /// El acumulado se persiste clampeado para que nunca supere el monto
  /// prestado, y el estado se deriva con la misma fórmula que expone
  /// `PrestamosLogic.estadoPrestamo` (duplicada aquí para que la BD quede
  /// coherente sin depender de la capa de presentación).
  ///
  /// Devuelve 0 si el préstamo no existe.
  Future<int> registrarPago(int id, double monto, {int? activoDestino}) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final mapas = await txn.query(
        Loan.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (mapas.isEmpty) return 0;
      final prestamo = Loan.fromMap(mapas.first);

      // Si la cuenta de origen se borró, el préstamo quedó sin activo: el
      // reembolso tiene que entrar a una cuenta que el usuario elija, o el
      // dinero aparecería de la nada.
      final activoId = activoDestino ?? prestamo.activoId;
      if (activoId == null) return 0;

      final montoPagado = (prestamo.montoPagado + monto)
          .clamp(0.0, prestamo.montoPrestado);

      await txn.insert(Transaction.tableName, {
        'tipo': Transaction.tipoIngreso,
        'monto': monto,
        'categoria': Loan.categoriaReembolso,
        'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'activo_id': activoId,
        'prestamo_id': id,
        'nota': 'Reembolso de ${prestamo.nombreBeneficiario}',
        'fecha_creacion':
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });

      await ActivoRepository.ajustarSaldoEnTransaccion(
        txn,
        activoId: activoId,
        delta: ActivoRepository.deltaDeMovimiento(
          Transaction.tipoIngreso,
          monto,
        ),
      );

      return txn.update(
        Loan.tableName,
        {
          'monto_pagado': montoPagado,
          'estado': _derivarEstado(prestamo.montoPrestado, montoPagado),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Movimiento de salida del dinero al prestar: resta del activo de origen y
  /// queda amarrado al préstamo para poder revertirlo con él.
  Future<void> _escribirMovimientoDeSalida(
    DatabaseExecutor txn,
    Loan prestamo, {
    required double monto,
    required int? activoId,
  }) async {
    final ahora = DateTime.now();
    await txn.insert(Transaction.tableName, {
      'tipo': Transaction.tipoGasto,
      'monto': monto,
      'categoria': Loan.categoriaPrestamo,
      'fecha': DateFormat('yyyy-MM-dd').format(prestamo.fechaPrestamo),
      'activo_id': activoId,
      'prestamo_id': prestamo.id,
      'nota': 'Préstamo a ${prestamo.nombreBeneficiario}',
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(ahora),
    });

    if (activoId == null) return;
    await ActivoRepository.ajustarSaldoEnTransaccion(
      txn,
      activoId: activoId,
      delta: ActivoRepository.deltaDeMovimiento(
        Transaction.tipoGasto,
        monto,
      ),
    );
  }

  /// Reembolsos ya registrados de un préstamo, tomados de sus movimientos.
  ///
  /// Se leen de `movimientos` y no de `monto_pagado` porque es el historial lo
  /// que hay que preservar al editar: un acumulado es un número, no una lista
  /// de pagos con fecha y nota.
  Future<List<Transaction>> _reembolsosRegistrados(
    DatabaseExecutor txn,
    int prestamoId,
  ) async {
    final mapas = await txn.query(
      Transaction.tableName,
      where: 'prestamo_id = ? AND categoria = ?',
      whereArgs: [prestamoId, Loan.categoriaReembolso],
      orderBy: 'fecha_creacion ASC',
    );
    return mapas.map(Transaction.fromMap).toList();
  }

  /// Deshace todo el impacto de un préstamo: borra sus movimientos devolviendo
  /// a cada activo el monto que ese movimiento le había aplicado.
  Future<void> _revertirMovimientos(
    DatabaseExecutor txn,
    int prestamoId,
  ) async {
    final mapas = await txn.query(
      Transaction.tableName,
      where: 'prestamo_id = ?',
      whereArgs: [prestamoId],
    );
    for (final mapa in mapas) {
      final movimiento = Transaction.fromMap(mapa);
      final activoId = movimiento.activoId;
      if (activoId != null) {
        await ActivoRepository.ajustarSaldoEnTransaccion(
          txn,
          activoId: activoId,
          delta: -ActivoRepository.deltaDeMovimiento(
            movimiento.tipo,
            movimiento.monto,
          ),
        );
      }
      await txn.delete(
        Transaction.tableName,
        where: 'id = ?',
        whereArgs: [movimiento.id],
      );
    }
  }

  String _fechaDe(Transaction movimiento) =>
      DateFormat('yyyy-MM-dd').format(movimiento.fecha);

  String _fechaCreacionDe(Transaction movimiento) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(movimiento.fechaCreacion);

  /// derive del estado: pagado_total si el acumulado alcanza (o supera por
  /// redondeo) el monto prestado; pagado_parcial si hay pagos parciales.
  static String _derivarEstado(double montoPrestado, double montoPagado) {
    const epsilon = 0.009;
    if (montoPagado + epsilon >= montoPrestado) return 'pagado_total';
    if (montoPagado > 0) return 'pagado_parcial';
    return 'pendiente';
  }
}