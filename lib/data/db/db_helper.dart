import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/asset.dart';
import '../models/transaction.dart';
import '../models/financial_goal.dart';
import '../models/loan.dart';
import '../models/investment.dart';
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

  static const int _dbVersion = 9;
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
    batch.execute(Loan.createTableSQL);
    batch.execute(Investment.createTableSQL);
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
      Loan.tableName,
      Investment.tableName,
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