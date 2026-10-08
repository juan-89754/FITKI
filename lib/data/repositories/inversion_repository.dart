import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/investment.dart';
import '../models/inversion_movimiento.dart';
import '../models/transaction.dart';
import '../db/db_helper.dart';
import '../../logic/categorias/categoria_labels.dart';
import 'activo_repository.dart';
import 'meta_repository.dart';

/// Una operación sobre una inversión que no tiene sentido con los datos
/// actuales (no hay saldo disponible, no hay capital reservado, ya está
/// finalizada, etc.). Se lanza para que la pantalla pueda explicar por qué.
class OperacionInversionInvalida implements Exception {
  final String mensaje;

  const OperacionInversionInvalida(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Inversiones conectadas al dinero, con la misma regla que las metas:
///
/// **Aportar a una inversión no mueve dinero de la cuenta.** El dinero sigue
/// dentro del activo; lo que cambia es que deja de estar disponible y queda
/// reservado en la inversión. Por eso un aporte no escribe un movimiento ni
/// toca `activos.monto_disponible`.
///
/// El capital (`monto_invertido`) y el resultado (`ganancia_obtenida`) se
/// derivan del historial de `inversiones_movimientos`, nunca se escriben a
/// mano. Al finalizar la inversión, el resultado neto se registra **una sola
/// vez** como movimiento real (ingreso si ganó, gasto si perdió), que sí ajusta
/// el saldo de la cuenta.
class InversionRepository {
  final DbHelper _dbHelper = DbHelper();

  /// Crea la inversión y, si trae cuenta de origen y monto, registra el aporte
  /// inicial que reserva ese dinero.
  Future<int> insert(Investment inversion) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      if (inversion.montoInvertido <= 0) {
        throw const OperacionInversionInvalida(
          'El monto invertido debe ser mayor a 0.',
        );
      }
      if (inversion.activoId == null) {
        throw const OperacionInversionInvalida(
          'Elige la cuenta de donde sale el dinero.',
        );
      }
      final disponible =
          await MetaRepository.saldoDisponibleDe(txn, inversion.activoId!);
      if (inversion.montoInvertido > disponible) {
        throw OperacionInversionInvalida(
          'La cuenta no tiene saldo disponible suficiente. '
          'Disponible: \$${disponible.toStringAsFixed(2)}.',
        );
      }
      final id = await txn.insert(Investment.tableName, inversion.toMap());
      await _insertarMovimiento(
        txn,
        inversionId: id,
        tipo: InversionMovimiento.tipoAporte,
        monto: inversion.montoInvertido,
        fecha: inversion.fecha,
        activoId: inversion.activoId,
        nota: null,
      );
      await _refrescarTotales(txn, id);
      return id;
    });
  }

  Future<List<Investment>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Investment.tableName,
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((map) => Investment.fromMap(map)).toList();
  }

  Future<Investment?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      Investment.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Investment.fromMap(maps.first);
  }

  /// Actualiza los datos descriptivos de la inversión (tipo, tasa, notas,
  /// fecha). No toca el capital ni el resultado: esos salen del historial.
  Future<int> update(Investment inversion) async {
    final db = await _dbHelper.database;
    return await db.update(
      Investment.tableName,
      {
        'tipo': inversion.tipo,
        'tasa_rendimiento': inversion.tasaRendimiento,
        'periodo_tasa': inversion.periodoTasa,
        'ganancia_proyectada': inversion.gananciaProyectada,
        'fecha': DateFormat('yyyy-MM-dd').format(inversion.fecha),
        'notas': inversion.notas,
      },
      where: 'id = ?',
      whereArgs: [inversion.id],
    );
  }

  /// Elimina la inversión y su historial. El capital reservado vuelve a estar
  /// disponible solo: la reserva se calcula sobre las inversiones activas, así
  /// que al desaparecer la fila deja de restar.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await txn.delete(
        InversionMovimiento.tableName,
        where: 'inversion_id = ?',
        whereArgs: [id],
      );
      return txn.delete(
        Investment.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<InversionMovimiento>> getMovimientosDe(int inversionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      InversionMovimiento.tableName,
      where: 'inversion_id = ?',
      whereArgs: [inversionId],
      orderBy: 'fecha DESC, fecha_creacion DESC',
    );
    return maps.map((map) => InversionMovimiento.fromMap(map)).toList();
  }

  /// Dinero de [activoId] que está reservado en inversiones **activas**. Las
  /// inversiones finalizadas ya liberaron su capital, por eso se excluyen.
  static Future<double> saldoReservadoEnActivo(
    DatabaseExecutor db,
    int activoId,
  ) async {
    final filas = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE WHEN m.tipo = ? THEN m.monto ELSE -m.monto END
      ), 0) AS total
      FROM ${InversionMovimiento.tableName} m
      JOIN ${Investment.tableName} i ON i.id = m.inversion_id
      WHERE m.activo_id = ?
        AND i.estado = ?
        AND m.tipo IN (?, ?)
      ''',
      [
        InversionMovimiento.tipoAporte,
        activoId,
        Investment.estadoActiva,
        InversionMovimiento.tipoAporte,
        InversionMovimiento.tipoRetiro,
      ],
    );
    return (filas.first['total'] as num).toDouble();
  }

  /// Saldo Disponible real de una cuenta: su Saldo Total menos lo reservado en
  /// metas y menos lo reservado en inversiones.
  static Future<double> saldoDisponibleDe(
    DatabaseExecutor db,
    int activoId,
  ) async {
    final activos = await db.query(
      'activos',
      columns: ['monto_disponible'],
      where: 'id = ?',
      whereArgs: [activoId],
    );
    if (activos.isEmpty) return 0;
    final total = (activos.first['monto_disponible'] as num).toDouble();
    final reservadoMetas =
        await MetaRepository.saldoReservadoEnActivo(db, activoId);
    final reservadoInversiones = await saldoReservadoEnActivo(db, activoId);
    return total - reservadoMetas - reservadoInversiones;
  }

  /// Registra un aporte de capital y refresca el capital de la inversión.
  Future<int> registrarAporte({
    required int inversionId,
    required double monto,
    required int activoId,
    required DateTime fecha,
    String? nota,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _validarInversionActiva(txn, inversionId);
      if (monto <= 0) {
        throw const OperacionInversionInvalida(
          'El monto del aporte debe ser mayor a 0.',
        );
      }
      final disponible = await saldoDisponibleDe(txn, activoId);
      if (monto > disponible) {
        throw OperacionInversionInvalida(
          'La cuenta no tiene saldo disponible suficiente. '
          'Disponible: \$${disponible.toStringAsFixed(2)}.',
        );
      }
      final id = await _insertarMovimiento(
        txn,
        inversionId: inversionId,
        tipo: InversionMovimiento.tipoAporte,
        monto: monto,
        fecha: fecha,
        activoId: activoId,
        nota: nota,
      );
      await _refrescarTotales(txn, inversionId);
      return id;
    });
  }

  /// Saca capital de la inversión y lo devuelve al Saldo Disponible.
  Future<int> registrarRetiro({
    required int inversionId,
    required double monto,
    required int activoId,
    required DateTime fecha,
    String? nota,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _validarInversion(txn, inversionId);
      if (monto <= 0) {
        throw const OperacionInversionInvalida(
          'El monto del retiro debe ser mayor a 0.',
        );
      }
      final reservado = await _reservadoDeInversion(txn, inversionId);
      if (monto > reservado) {
        throw OperacionInversionInvalida(
          'La inversión no tiene ese capital reservado. '
          'Reservado: \$${reservado.toStringAsFixed(2)}.',
        );
      }
      final id = await _insertarMovimiento(
        txn,
        inversionId: inversionId,
        tipo: InversionMovimiento.tipoRetiro,
        monto: monto,
        fecha: fecha,
        activoId: activoId,
        nota: nota,
      );
      await _refrescarTotales(txn, inversionId);
      return id;
    });
  }

  /// Registra una ganancia (resultado positivo) como detalle de la inversión.
  /// No toca la cuenta: solo suma al resultado, que se materializa al finalizar.
  Future<int> registrarGanancia({
    required int inversionId,
    required double monto,
    DateTime? fecha,
    String? nota,
  }) {
    return _registrarResultado(
      inversionId: inversionId,
      tipo: InversionMovimiento.tipoGanancia,
      monto: monto,
      fecha: fecha,
      nota: nota,
    );
  }

  /// Registra una pérdida (resultado negativo) como detalle de la inversión.
  Future<int> registrarPerdida({
    required int inversionId,
    required double monto,
    DateTime? fecha,
    String? nota,
  }) {
    return _registrarResultado(
      inversionId: inversionId,
      tipo: InversionMovimiento.tipoPerdida,
      monto: monto,
      fecha: fecha,
      nota: nota,
    );
  }

  Future<int> _registrarResultado({
    required int inversionId,
    required String tipo,
    required double monto,
    DateTime? fecha,
    String? nota,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _validarInversionActiva(txn, inversionId);
      if (monto < 0) {
        throw const OperacionInversionInvalida('El monto no puede ser negativo.');
      }
      final id = await _insertarMovimiento(
        txn,
        inversionId: inversionId,
        tipo: tipo,
        monto: monto,
        fecha: fecha ?? DateTime.now(),
        activoId: null,
        nota: nota,
      );
      await _refrescarTotales(txn, inversionId);
      return id;
    });
  }

  /// Finaliza la inversión: libera el capital reservado y registra el resultado
  /// neto en el historial de movimientos de la cuenta (ingreso si ganó, gasto
  /// si perdió). Marca la inversión como 'finalizada'.
  Future<void> finalizar(int inversionId, {DateTime? fecha}) async {
    final db = await _dbHelper.database;
    await db.transaction<void>((txn) async {
      final inversion = await _validarInversion(txn, inversionId);
      if (!inversion.estaActiva) {
        throw const OperacionInversionInvalida('La inversión ya está finalizada.');
      }

      final resultado = await _resultadoDeInversion(txn, inversionId);
      final activoId = inversion.activoId;
      final fechaMov = fecha ?? DateTime.now();

      if (resultado.abs() > 0.009 && activoId != null) {
        final esGanancia = resultado > 0;
        final categoria = esGanancia
            ? categoriaGananciaInversion
            : categoriaPerdidaInversion;
        await txn.insert(Transaction.tableName, {
          'tipo': esGanancia ? Transaction.tipoIngreso : Transaction.tipoGasto,
          'monto': resultado.abs(),
          'categoria': categoria,
          'fecha': DateFormat('yyyy-MM-dd').format(fechaMov),
          'activo_id': activoId,
          'nota': 'Resultado de inversión',
          'fecha_creacion':
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        });
        await ActivoRepository.ajustarSaldoEnTransaccion(
          txn,
          activoId: activoId,
          delta: ActivoRepository.deltaDeMovimiento(
            esGanancia ? Transaction.tipoIngreso : Transaction.tipoGasto,
            resultado.abs(),
          ),
        );
      }

      await txn.update(
        Investment.tableName,
        {'estado': Investment.estadoFinalizada},
        where: 'id = ?',
        whereArgs: [inversionId],
      );
    });
  }

  Future<int> _insertarMovimiento(
    DatabaseExecutor txn, {
    required int inversionId,
    required String tipo,
    required double monto,
    required DateTime fecha,
    required int? activoId,
    String? nota,
  }) {
    final movimiento = InversionMovimiento(
      inversionId: inversionId,
      tipo: tipo,
      monto: monto,
      fecha: fecha,
      activoId: activoId,
      nota: nota,
      fechaCreacion: DateTime.now(),
    );
    return txn.insert(InversionMovimiento.tableName, movimiento.toMap());
  }

  /// Recalcula el capital reservado y el resultado de la inversión a partir de
  /// su historial, para que los dos números nunca queden descuadrados.
  static Future<void> _refrescarTotales(
    DatabaseExecutor txn,
    int inversionId,
  ) async {
    final filas = await txn.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE
          WHEN tipo = ? THEN monto
          WHEN tipo = ? THEN -monto
          ELSE 0 END), 0) AS capital,
        COALESCE(SUM(CASE
          WHEN tipo = ? THEN monto
          WHEN tipo = ? THEN -monto
          ELSE 0 END), 0) AS resultado
      FROM ${InversionMovimiento.tableName}
      WHERE inversion_id = ?
      ''',
      [
        InversionMovimiento.tipoAporte,
        InversionMovimiento.tipoRetiro,
        InversionMovimiento.tipoGanancia,
        InversionMovimiento.tipoPerdida,
        inversionId,
      ],
    );
    final capital = (filas.first['capital'] as num).toDouble();
    final resultado = (filas.first['resultado'] as num).toDouble();
    await txn.update(
      Investment.tableName,
      {'monto_invertido': capital, 'ganancia_obtenida': resultado},
      where: 'id = ?',
      whereArgs: [inversionId],
    );
  }

  static Future<double> _reservadoDeInversion(
    DatabaseExecutor txn,
    int inversionId,
  ) async {
    final filas = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN tipo = ? THEN monto ELSE -monto END), 0) AS total
      FROM ${InversionMovimiento.tableName}
      WHERE inversion_id = ? AND tipo IN (?, ?)
      ''',
      [
        InversionMovimiento.tipoAporte,
        inversionId,
        InversionMovimiento.tipoAporte,
        InversionMovimiento.tipoRetiro,
      ],
    );
    return (filas.first['total'] as num).toDouble();
  }

  static Future<double> _resultadoDeInversion(
    DatabaseExecutor txn,
    int inversionId,
  ) async {
    final filas = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN tipo = ? THEN monto ELSE -monto END), 0) AS total
      FROM ${InversionMovimiento.tableName}
      WHERE inversion_id = ? AND tipo IN (?, ?)
      ''',
      [
        InversionMovimiento.tipoGanancia,
        inversionId,
        InversionMovimiento.tipoGanancia,
        InversionMovimiento.tipoPerdida,
      ],
    );
    return (filas.first['total'] as num).toDouble();
  }

  Future<Investment> _validarInversion(
    DatabaseExecutor txn,
    int inversionId,
  ) async {
    final maps = await txn.query(
      Investment.tableName,
      where: 'id = ?',
      whereArgs: [inversionId],
    );
    if (maps.isEmpty) {
      throw const OperacionInversionInvalida('La inversión no existe.');
    }
    return Investment.fromMap(maps.first);
  }

  Future<Investment> _validarInversionActiva(
    DatabaseExecutor txn,
    int inversionId,
  ) async {
    final inversion = await _validarInversion(txn, inversionId);
    if (!inversion.estaActiva) {
      throw const OperacionInversionInvalida('La inversión ya está finalizada.');
    }
    return inversion;
  }
}