import 'package:fitki/data/db/db_helper.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/repositories/activo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

/// Tests de `DbHelper.vaciarDatos` sobre una base SQLite real en memoria.
///
/// Vaciar los datos debe dejar el esquema intacto y reiniciar los contadores
/// AUTOINCREMENT (`sqlite_sequence`), para que la app quede de verdad como
/// recién instalada. Esto protege ese contrato.
void main() {
  late DbHelper dbHelper;
  late ActivoRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Base aislada por archivo de test: evita que varios tests que comparten
    // el mismo `fitki.db` en disco se bloqueen entre sí.
    DbHelper.rutaParaTests = inMemoryDatabasePath;
  });

  setUp(() async {
    dbHelper = DbHelper();
    repo = ActivoRepository();
    await dbHelper.database;
    await dbHelper.vaciarDatos();
  });

  tearDownAll(() async {
    await DbHelper().close();
  });

  Future<int> crearActivo() {
    return repo.insert(
      Asset(
        nombre: 'Banco',
        tipo: 'cuenta_bancaria',
        montoDisponible: 1000,
        moneda: 'COP',
        fechaCreacion: DateTime(2026, 1, 1),
      ),
    );
  }

  test('vacía las tablas pero conserva el esquema', () async {
    final db = await dbHelper.database;
    await crearActivo();
    await db.insert(
      FinancialGoal.tableName,
      FinancialGoal(
        nombre: 'Viaje',
        finalidad: 'vacaciones',
        montoAhorrado: 0,
        fechaCreacion: DateTime(2026, 1, 1),
      ).toMap(),
    );

    await dbHelper.vaciarDatos();

    expect(await db.query(Asset.tableName), isEmpty);
    expect(await db.query(FinancialGoal.tableName), isEmpty);
    // El esquema sigue ahí: se puede volver a insertar.
    expect(await crearActivo(), greaterThan(0));
  });

  test('reinicia los ids AUTOINCREMENT a 1', () async {
    final primerId = await crearActivo();
    expect(primerId, greaterThan(0));

    final db = await dbHelper.database;
    final movId = await db.insert(
      Transaction.tableName,
      Transaction(
        tipo: Transaction.tipoGasto,
        monto: 10,
        categoria: 'cafe',
        fecha: DateTime(2026, 2, 1),
        fechaCreacion: DateTime(2026, 2, 1),
      ).toMap(),
    );
    expect(movId, greaterThan(0));

    await dbHelper.vaciarDatos();

    expect(await crearActivo(), 1,
        reason: 'el id vuelve a empezar en 1 tras reiniciar sqlite_sequence');
  });

  test('es idempotente y no falla sin filas previas', () async {
    // La primera corrida es sobre una base recién creada, sin sqlite_sequence
    // (nunca se insertó nada); no debe lanzar.
    await dbHelper.vaciarDatos();
    await dbHelper.vaciarDatos();

    expect(await crearActivo(), 1);
  });
}
