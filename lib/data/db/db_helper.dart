import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/abono_meta.dart';
import '../models/asset.dart';
import '../models/transaction.dart';
import '../models/financial_goal.dart';
import '../models/loan.dart';
import '../models/investment.dart';
import '../models/inversion_movimiento.dart';
import '../models/debt.dart';
import '../models/quote_project.dart';
import '../models/quote.dart';
import '../models/quote_item.dart';
import '../models/gasto_fijo.dart';
import '../models/pago_gasto_fijo.dart';
import '../models/presupuesto_activo.dart';
import '../models/categoria_personalizada.dart';
import '../models/perfil.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static sqflite.Database? _database;

  factory DbHelper() => _instance;

  DbHelper._internal();

  static const int _dbVersion = 14;
  static const String _dbName = 'fitki.db';

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Ruta del archivo .db actual (la misma que usa [database] para abrir la
  /// conexión). Es útil para copiar el archivo completo (backup/restauración).
  static Future<String> getDatabasePath() async {
    return join(await sqflite.getDatabasesPath(), _dbName);
  }

  Future<sqflite.Database> _initDatabase() async {
    final path = await getDatabasePath();
    return await sqflite.openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    final batch = db.batch();

    batch.execute(Asset.createTableSQL);
    batch.execute(Transaction.createTableSQL);
    batch.execute(FinancialGoal.createTableSQL);
    batch.execute(AbonoMeta.createTableSQL);
    batch.execute(Loan.createTableSQL);
    batch.execute(Investment.createTableSQL);
    batch.execute(InversionMovimiento.createTableSQL);
    batch.execute(Debt.createTableSQL);
    batch.execute(QuoteProject.createTableSQL);
    batch.execute(Quote.createTableSQL);
    batch.execute(QuoteItem.createTableSQL);
    batch.execute(GastoFijo.createTableSQL);
    batch.execute(PagoGastoFijo.createTableSQL);
    batch.execute(PresupuestoActivo.createTableSQL);
    batch.execute(CategoriaPersonalizada.createTableSQL);
    batch.execute(Perfil.createTableSQL);

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE items_cotizacion ADD COLUMN costos_adicionales_detalle TEXT',
      );
    }
    if (oldVersion < 3) {
      // El modelo Investment ahora declara el período de su tasa; sin esta
      // columna las instalaciones existentes no podrían leerla.
      await db.execute(
        "ALTER TABLE inversiones ADD COLUMN periodo_tasa TEXT NOT NULL DEFAULT 'anual'",
      );
      // El modelo Loan ahora acumula pagos parciales; necesaria para derivar
      // el estado del préstamo a partir del monto ya pagado.
      await db.execute(
        'ALTER TABLE prestamos ADD COLUMN monto_pagado REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      // Módulo de Configuraciones: perfil y categorías personalizadas.
      // Se reutiliza el mismo SQL declarado por cada modelo (createTableSQL)
      // para que esta migración nunca diverja del esquema inicial.
      await db.execute(CategoriaPersonalizada.createTableSQL);
      await db.execute(Perfil.createTableSQL);
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE items_cotizacion ADD COLUMN tipo TEXT NOT NULL DEFAULT 'producto'",
      );
    }
    if (oldVersion < 8) {
      // Las deudas ahora conocen su monto inicial para calcular el progreso de
      // pago; las instalaciones antiguas toman su pendiente actual como base.
      // El bloque de presupuestos que vivía aquí ya no aplica: la v9 elimina
      // esas tablas y crea su reemplazo.
      await db.execute(Debt.columnaMontoInicialSQL);
      await db.execute(
        'UPDATE ${Debt.tableName} SET monto_inicial = monto_pendiente '
        'WHERE monto_inicial IS NULL',
      );
    }
    if (oldVersion < 9) {
      // El módulo de presupuesto se rehace: el gasto hormiga desaparece y el
      // presupuesto pasa a ser un límite por activo. Las tablas anteriores
      // (gastos_diarios, presupuestos, gastos_presupuestados) quedan fuera del
      // esquema; los movimientos nunca se tocan porque son el historial real
      // del dinero y la fuente de la que se calcula lo gastado.
      //
      // Los nombres van como texto literal a propósito: esos modelos ya no
      // existen en el código, y una base vieja sí puede tener esas tablas.
      for (final tabla in [
        'gastos_diarios',
        'presupuestos',
        'gastos_presupuestados',
      ]) {
        await db.execute('DROP TABLE IF EXISTS $tabla');
      }
      await db.execute(GastoFijo.createTableSQL);
      await db.execute(PagoGastoFijo.createTableSQL);
      await db.execute(PresupuestoActivo.createTableSQL);
    }
    if (oldVersion < 10) {
      // Los abonos a las metas pasan a ser registros con historia propia: cada
      // aporte guarda de qué cuenta salió, cuándo y qué movimiento de gasto
      // generó, para poder quitarlo después devolviendo el dinero. Antes solo
      // se sumaba al acumulado de la meta, sin origen ni reversa posible.
      await db.execute(AbonoMeta.createTableSQL);
    }
    if (oldVersion < 11) {
      // Los préstamos a terceros se conectan con el dinero: el préstamo guarda
      // de qué cuenta salió y cada movimiento que genera queda amarrado a él.
      // Sin `prestamos.activo_id` no hay contra qué descontar lo prestado ni
      // dónde devolver lo que se reembolse, que es justo lo que se perdía
      // antes. `movimientos.prestamo_id` es lo que permite borrar el préstamo
      // junto con sus movimientos devolviendo el dinero, sin adivinar a qué
      // préstamo pertenece cada movimiento por su categoría o su nota.
      await db.execute(
        'ALTER TABLE prestamos ADD COLUMN activo_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE movimientos ADD COLUMN prestamo_id INTEGER',
      );
    }
    if (oldVersion < 12) {
      // Una meta es dinero que se puede meter y sacar en cualquier momento, así
      // que sus registros dejan de ser solo aportes: cada fila dice si el dinero
      // entró a la meta o salió de ella. Todas las filas existentes son aportes,
      // de ahí el valor por defecto.
      //
      // `movimiento_id` queda en la tabla aunque ya no se use: un aporte a una
      // meta no crea un movimiento, porque no mueve el saldo real de la cuenta,
      // solo su disponibilidad. Y como las claves foráneas no están
      // habilitadas, quitar la columna exigiría reescribir la tabla y con ella
      // el historial de los aportes.

      // `abonos_metas` es la única tabla que se crea dentro de una migración (el
      // bloque v10) y no únicamente en `_onCreate`. Una instalación que viene de
      // antes de la v10 recibe por tanto una tabla creada con el esquema actual,
      // que ya trae `tipo`, y volver a añadir la columna aborta la migración con
      // "duplicate column name", dejando la base sin abrir y la app muerta al
      // arrancar. La migración tiene que servir igual a las bases que no tienen
      // la columna y a las que nacieron en la v10 con ella ya incluida.
      final columnasAbono = await db.rawQuery(
        'PRAGMA table_info(${AbonoMeta.tableName})',
      );
      final yaTieneTipo = columnasAbono.any(
        (columna) => columna['name'] == AbonoMeta.columnaTipo,
      );
      if (!yaTieneTipo) {
        await db.execute(
          'ALTER TABLE ${AbonoMeta.tableName} '
          "ADD COLUMN tipo TEXT NOT NULL DEFAULT '${AbonoMeta.tipoAporte}'",
        );
      }

      // Los abonos que la versión anterior sí descontaban de la cuenta dejaban el
      // Saldo Total de los activos infracontabilizado, y sus movimientos de gasto
      // seguían en `movimientos` como si el dinero se hubiera gastado. Se
      // deshacen aquí: el dinero vuelve a su cuenta, sus movimientos se borran y
      // el registro queda solo como aporto a la meta (tipo 'aporte', sin
      // movimiento), que es exactamente lo que representa.
      await db.execute('''
        UPDATE activos SET monto_disponible = monto_disponible + COALESCE((
          SELECT SUM(a.monto) FROM abonos_metas a
          WHERE a.activo_id = activos.id AND a.movimiento_id IS NOT NULL
        ), 0)
      ''');
      await db.execute('''
        DELETE FROM movimientos WHERE id IN (
          SELECT movimiento_id FROM abonos_metas WHERE movimiento_id IS NOT NULL
        )
      ''');
      await db.execute(
        'UPDATE abonos_metas SET movimiento_id = NULL WHERE movimiento_id IS NOT NULL',
      );
    }
    if (oldVersion < 13) {
      await db.execute(
        'ALTER TABLE ${Transaction.tableName} ADD COLUMN comprobante_path TEXT',
      );
      await db.execute(
        'ALTER TABLE ${Transaction.tableName} ADD COLUMN comprobante_nombre TEXT',
      );
      await db.execute(
        'ALTER TABLE ${Transaction.tableName} ADD COLUMN comprobante_mime_type TEXT',
      );
      await db.execute(
        'ALTER TABLE ${Transaction.tableName} ADD COLUMN comprobante_size_bytes INTEGER',
      );
    }
    if (oldVersion < 14) {
      // Las inversiones pasan a comportarse como las metas: su dinero se liga a
      // una cuenta de origen y se reserva desde ella. `activo_id` es esa cuenta
      // y `estado` distingue una inversión abierta de una ya finalizada, cuando
      // el resultado se registra en el historial de movimientos.
      await db.execute('ALTER TABLE inversiones ADD COLUMN activo_id INTEGER');
      await db.execute(
        "ALTER TABLE inversiones ADD COLUMN estado TEXT NOT NULL DEFAULT 'activa'",
      );
      // Historial de aportes, retiros, ganancias y pérdidas de cada inversión.
      await db.execute(InversionMovimiento.createTableSQL);
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  /// Vacía todas las tablas de la base (borra el contenido, conserva el
  /// esquema). Cada modelo expone su [tableName]; la lista se mantiene
  /// alineada con `_onCreate` para no olvidar tablas nuevas.
  Future<void> vaciarDatos() async {
    final db = await database;
    final batch = db.batch();
    for (final tabla in [
      Asset.tableName,
      Transaction.tableName,
      FinancialGoal.tableName,
      AbonoMeta.tableName,
      Loan.tableName,
      Investment.tableName,
      InversionMovimiento.tableName,
      Debt.tableName,
      QuoteProject.tableName,
      Quote.tableName,
      QuoteItem.tableName,
      GastoFijo.tableName,
      PagoGastoFijo.tableName,
      PresupuestoActivo.tableName,
      CategoriaPersonalizada.tableName,
      Perfil.tableName,
    ]) {
      batch.execute('DELETE FROM $tabla');
    }
    await batch.commit(noResult: true);
  }
}