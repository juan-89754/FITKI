import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../db/db_helper.dart';
import '../models/abono_meta.dart';
import '../models/financial_goal.dart';
import 'inversion_repository.dart';

/// Una operación sobre una meta que no tiene sentido con los datos actuales.
///
/// Se lanza en vez de devolver un código para que la pantalla pueda explicar
/// *por qué* se rechazó, que es justo lo que el usuario necesita ver: no alcanza
/// el saldo de la cuenta, la meta no tiene ese monto reservado, o la cuenta ya no
/// existe.
class OperacionMetaInvalida implements Exception {
  final String mensaje;

  const OperacionMetaInvalida(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Reservas y aportes de metas.
///
/// **La regla central: un aporte a una meta no mueve dinero de la cuenta.** El
/// dinero sigue en el activo; lo que cambia es que pasa de "disponible" a
/// "reservado en esta meta". Por eso aquí no se escribe ningún movimiento en
/// `movimientos` ni se toca `activos.monto_disponible`: esas dos cosas son
/// territorio de los ingresos y gastos reales.
///
/// En la base de datos, `movimientos` son todos gastos, pero un aporte no lo es:
/// el dinero no salió de la cuenta, y anotarlo como gasto hacía que el saldo del
/// activo no cuadrara con su propio historial. Como esta versión no toca la
/// cuenta, el aporte se registra solo en `abonos_metas` y su efecto se refleja
/// en el Saldo Disponible, que se calcula restando las reservas al Saldo Total.
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

  /// Actualiza los datos editables de la meta.
  ///
  /// `monto_ahorrado` se excluye a propósito: no es un campo que el usuario
  /// escriba, es el acumulado que [registrarAporte], [registrarRetiro] y
  /// [eliminarRegistro] mantienen siempre derivado de los registros, dentro de la
  /// misma transacción que los escribe. Grabar el valor que traía el formulario
  /// podría pisar un aporte registrado mientras la pantalla de edición estaba
  /// abierta.
  Future<int> update(FinancialGoal meta) async {
    final db = await _dbHelper.database;
    return await db.update(
      FinancialGoal.tableName,
      {
        'nombre': meta.nombre,
        'monto_objetivo': meta.montoObjetivo,
        'finalidad': meta.finalidad,
        'fecha_estimada': meta.fechaEstimada != null
            ? DateFormat('yyyy-MM-dd').format(meta.fechaEstimada!)
            : null,
        'comentarios': meta.comentarios,
      },
      where: 'id = ?',
      whereArgs: [meta.id],
    );
  }

  /// Elimina la meta y su historial de aportes y retiros.
  ///
  /// No devuelve dinero a ninguna cuenta, y es a propósito: el dinero de un
  /// aporte nunca salió del activo, así que borrar la meta no tiene nada que
  /// revertir en la cuenta. Solo desaparece la reserva, y con ella el dinero
  /// vuelve a estar disponible para gastarse.
  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await txn.delete(
        AbonoMeta.tableName,
        where: 'meta_id = ?',
        whereArgs: [id],
      );
      return txn.delete(
        FinancialGoal.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Aportes y retiros de una meta, del más reciente al más antiguo.
  Future<List<AbonoMeta>> getRegistrosDe(int metaId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AbonoMeta.tableName,
      where: 'meta_id = ?',
      whereArgs: [metaId],
      orderBy: 'fecha DESC, fecha_creacion DESC',
    );
    return maps.map((map) => AbonoMeta.fromMap(map)).toList();
  }

  /// Aportes y retiros de **todas** las metas.
  ///
  /// El Saldo Disponible de un activo necesita las reservas de todas las metas,
  /// no solo de una: el dinero reservado sale de una cuenta, así que se suma por
  /// cuenta, y esa suma solo existe si se miran todos los registros a la vez.
  Future<List<AbonoMeta>> getAllRegistros() async {
    final db = await _dbHelper.database;
    final maps = await db.query(AbonoMeta.tableName);
    return maps.map((map) => AbonoMeta.fromMap(map)).toList();
  }

  /// Dinero de [activoId] que está reservado en metas, para mostrar el Saldo
  /// Disponible y para validar que un aporte no gaste dinero ya comprometido.
  static Future<double> saldoReservadoEnActivo(
    DatabaseExecutor db,
    int activoId,
  ) async {
    final filas = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN tipo = ? THEN monto ELSE -monto END), 0) AS total
      FROM ${AbonoMeta.tableName}
      WHERE activo_id = ?
      ''',
      [AbonoMeta.tipoAporte, activoId],
    );
    return (filas.first['total'] as num).toDouble();
  }

  /// Saldo Total del activo menos lo que tiene reservado en metas y en
  /// inversiones activas: es el dinero que todavía se puede apartar o gastar.
  static Future<double> saldoDisponibleDe(DatabaseExecutor db, int activoId) async {
    final activos = await db.query(
      'activos',
      columns: ['monto_disponible'],
      where: 'id = ?',
      whereArgs: [activoId],
    );
    if (activos.isEmpty) return 0;
    final total = (activos.first['monto_disponible'] as num).toDouble();
    final reservadoMetas = await saldoReservadoEnActivo(db, activoId);
    final reservadoInversiones =
        await InversionRepository.saldoReservadoEnActivo(db, activoId);
    return total - reservadoMetas - reservadoInversiones;
  }

  /// Aparta [monto] del Saldo Disponible de [activoId] y lo suma al saldo de la
  /// meta.
  ///
  /// Lo que hace, en una sola transacción:
  /// 1. Valida que la meta y la cuenta existan y que el monto sea positivo.
  /// 2. Valida que la cuenta tenga [monto] **disponible**, es decir, que no esté
///    ya comprometido en otra meta. Apartar dinero reservado no es restarle a
  ///    otra meta: es evitar que dos metas compitan por el mismo peso.
  /// 3. Inserta el registro del aporte.
  /// 4. Refresca `monto_ahorrado` de la meta con la suma de sus registros.
  ///
  /// No escribe movimientos ni toca el saldo del activo, porque el dinero no
  /// cambió de cuenta: solo dejó de estar disponible para gastar.
  ///
  /// Lanza [OperacionMetaInvalida] si el aporte no es válido.
  Future<int> registrarAporte({
    required int metaId,
    required double monto,
    required int activoId,
    required DateTime fecha,
    String? nota,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _validarMetaYActivo(txn, metaId: metaId, activoId: activoId);
      if (monto <= 0) {
        throw const OperacionMetaInvalida('El monto del aporte debe ser mayor a 0.');
      }

      final disponible = await saldoDisponibleDe(txn, activoId);
      if (monto > disponible) {
        throw OperacionMetaInvalida(
          'La cuenta no tiene saldo disponible suficiente. '
          'Disponible: \$${disponible.toStringAsFixed(2)}.',
        );
      }

      final aporte = AbonoMeta(
        metaId: metaId,
        tipo: AbonoMeta.tipoAporte,
        monto: monto,
        fecha: fecha,
        activoId: activoId,
        nota: nota,
        fechaCreacion: DateTime.now(),
      );
      final id = await txn.insert(AbonoMeta.tableName, aporte.toMap());
      await _refrescarSaldoMeta(txn, metaId);
      return id;
    });
  }

  /// Saca [monto] de la meta y lo devuelve al Saldo Disponible de [activoId].
  ///
  /// Es la operación inversa de [registrarAporte] y valida lo mismo desde el otro
  /// lado: que la meta tenga [monto] reservado **en esa cuenta**. Retirar dinero
  /// que se apartó desde otra cuenta movería el Saldo Disponible de una cuenta
  /// que nunca lo apartó, y dejaría la otra con una reserva que ya no existe.
  ///
  /// Lanza [OperacionMetaInvalida] si el retiro no es válido.
  Future<int> registrarRetiro({
    required int metaId,
    required double monto,
    required int activoId,
    required DateTime fecha,
    String? nota,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      await _validarMetaYActivo(txn, metaId: metaId, activoId: activoId);
      if (monto <= 0) {
        throw const OperacionMetaInvalida('El monto del retiro debe ser mayor a 0.');
      }

      final reservado = await _reservadoDeMetaEnActivo(
        txn,
        metaId: metaId,
        activoId: activoId,
      );
      if (monto > reservado) {
        throw OperacionMetaInvalida(
          'La meta no tiene ese monto reservado en esa cuenta. '
          'Reservado aquí: \$${reservado.toStringAsFixed(2)}.',
        );
      }

      final retiro = AbonoMeta(
        metaId: metaId,
        tipo: AbonoMeta.tipoRetiro,
        monto: monto,
        fecha: fecha,
        activoId: activoId,
        nota: nota,
        fechaCreacion: DateTime.now(),
      );
      final id = await txn.insert(AbonoMeta.tableName, retiro.toMap());
      await _refrescarSaldoMeta(txn, metaId);
      return id;
    });
  }

  /// Quita un aporte o un retiro del historial.
  ///
  /// Solo borra la fila: el Saldo Total de las cuentas nunca se vio afectado por
  /// ella, y el Saldo Disponible se recalcula solo al desaparecer la reserva. El
  /// saldo de la meta sí se refresca, para que no quede mostrando dinero que ya
  /// no está registrado.
  Future<int> eliminarRegistro(int registroId) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final mapas = await txn.query(
        AbonoMeta.tableName,
        columns: ['meta_id'],
        where: 'id = ?',
        whereArgs: [registroId],
      );
      if (mapas.isEmpty) return 0;

      final metaId = mapas.first['meta_id'] as int;
      final borrados = await txn.delete(
        AbonoMeta.tableName,
        where: 'id = ?',
        whereArgs: [registroId],
      );
      await _refrescarSaldoMeta(txn, metaId);
      return borrados;
    });
  }

  Future<void> _validarMetaYActivo(
    DatabaseExecutor txn, {
    required int metaId,
    required int activoId,
  }) async {
    final metas = await txn.query(
      FinancialGoal.tableName,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [metaId],
    );
    if (metas.isEmpty) {
      throw const OperacionMetaInvalida('La meta ya no existe.');
    }

    final activos = await txn.query(
      'activos',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [activoId],
    );
    if (activos.isEmpty) {
      throw const OperacionMetaInvalida('La cuenta seleccionada ya no existe.');
    }
  }

  /// Reservado de una meta **en una cuenta concreta**: la suma con signo de los
  /// registros de esa meta que salieron de esa cuenta.
  static Future<double> _reservadoDeMetaEnActivo(
    DatabaseExecutor txn, {
    required int metaId,
    required int activoId,
  }) async {
    final filas = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN tipo = ? THEN monto ELSE -monto END), 0) AS total
      FROM ${AbonoMeta.tableName}
      WHERE meta_id = ? AND activo_id = ?
      ''',
      [AbonoMeta.tipoAporte, metaId, activoId],
    );
    return (filas.first['total'] as num).toDouble();
  }

  /// Único lugar donde se escribe `monto_ahorrado`, siempre dentro de la misma
  /// transacción que escribe o borra un registro.
  ///
  /// El valor no se acumula con `+`/`-` sobre lo que había, sino que se vuelve a
  /// sumar **desde cero** sobre los registros (Σ aportes − Σ retiros). Es lo que
  /// garantiza que el avance de la meta no pueda quedar descuadrado con su propio
  /// historial: si alguna vez se descuadrara, la siguiente operación lo arregla en
  /// lugar de propagar el error.
  static Future<void> _refrescarSaldoMeta(
    DatabaseExecutor txn,
    int metaId,
  ) async {
    final filas = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN tipo = ? THEN monto ELSE -monto END), 0) AS total
      FROM ${AbonoMeta.tableName}
      WHERE meta_id = ?
      ''',
      [AbonoMeta.tipoAporte, metaId],
    );
    await txn.update(
      FinancialGoal.tableName,
      {'monto_ahorrado': (filas.first['total'] as num).toDouble()},
      where: 'id = ?',
      whereArgs: [metaId],
    );
  }
}