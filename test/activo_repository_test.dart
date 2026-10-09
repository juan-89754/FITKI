import 'package:fitki/data/db/db_helper.dart';
import 'package:fitki/data/models/abono_meta.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/gasto_fijo.dart';
import 'package:fitki/data/models/inversion_movimiento.dart';
import 'package:fitki/data/models/investment.dart';
import 'package:fitki/data/models/loan.dart';
import 'package:fitki/data/models/presupuesto_activo.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/repositories/activo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

/// Tests del borrado de un activo sobre una base SQLite real en memoria.
///
/// Las claves foráneas no están habilitadas, así que las cascadas del esquema
/// las aplica [ActivoRepository.delete] a mano. Esta suite protege que el
/// borrado deje a TODO hijo sin referencia a la cuenta muerta (en NULL o
/// eliminado), sin tocar jamás los movimientos, que son el historial del dinero.
void main() {
  late ActivoRepository repo;
  late DbHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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

  Future<int> dbInsert(Object modelo) async {
    final db = await dbHelper.database;
    final tabla = (modelo is Asset)
        ? Asset.tableName
        : (modelo is FinancialGoal)
            ? FinancialGoal.tableName
            : (modelo is AbonoMeta)
                ? AbonoMeta.tableName
                : (modelo is GastoFijo)
                    ? GastoFijo.tableName
                    : (modelo is Loan)
                        ? Loan.tableName
                        : (modelo is Investment)
                            ? Investment.tableName
                            : (modelo is InversionMovimiento)
                                ? InversionMovimiento.tableName
                                : (modelo is PresupuestoActivo)
                                    ? PresupuestoActivo.tableName
                                    : Transaction.tableName;
    final mapa = switch (modelo) {
      Asset() => modelo.toMap(),
      FinancialGoal() => modelo.toMap(),
      AbonoMeta() => modelo.toMap(),
      GastoFijo() => modelo.toMap(),
      Loan() => modelo.toMap(),
      Investment() => modelo.toMap(),
      InversionMovimiento() => modelo.toMap(),
      PresupuestoActivo() => modelo.toMap(),
      Transaction() => modelo.toMap(),
      _ => throw ArgumentError('Modelo no soportado: $modelo'),
    };
    return db.insert(tabla, mapa);
  }

  Future<int> crearMeta() {
    return dbInsert(FinancialGoal(
      nombre: 'Viaje',
      finalidad: 'vacaciones',
      montoAhorrado: 0,
      fechaCreacion: DateTime(2026, 1, 1),
    ));
  }

  Future<List<Map<String, Object?>>> filas(String tabla) async {
    final db = await dbHelper.database;
    return db.query(tabla);
  }

  test('borra al activo dejando todos sus hijos con referencia limpia', () async {
    final activoId = await crearActivo();
    final metaId = await crearMeta();
    await dbInsert(AbonoMeta(
      metaId: metaId,
      tipo: AbonoMeta.tipoAporte,
      monto: 100,
      fecha: DateTime(2026, 2, 1),
      activoId: activoId,
      fechaCreacion: DateTime(2026, 2, 1),
    ));
    await dbInsert(GastoFijo(
      nombre: 'Internet',
      categoria: 'servicios',
      montoEstimado: 50,
      activoId: activoId,
      fechaInicio: DateTime(2026, 1, 1),
      fechaCreacion: DateTime(2026, 1, 1),
    ));
    await dbInsert(Loan(
      nombreBeneficiario: 'Ana',
      montoPrestado: 300,
      activoId: activoId,
      fechaPrestamo: DateTime(2026, 3, 1),
      fechaPagoEsperada: DateTime(2026, 4, 1),
      fechaCreacion: DateTime(2026, 3, 1),
    ));
    final inversionId = await dbInsert(Investment(
      tipo: 'bolsa',
      activoId: activoId,
      montoInvertido: 200,
      fecha: DateTime(2026, 3, 15),
      fechaCreacion: DateTime(2026, 3, 15),
    ));
    await dbInsert(InversionMovimiento(
      inversionId: inversionId,
      tipo: InversionMovimiento.tipoAporte,
      monto: 200,
      fecha: DateTime(2026, 3, 15),
      activoId: activoId,
      fechaCreacion: DateTime(2026, 3, 15),
    ));
    await dbInsert(PresupuestoActivo(
      activoId: activoId,
      mes: 4,
      anio: 2026,
      montoLimite: 500,
      fechaCreacion: DateTime(2026, 4, 1),
    ));
    await dbInsert(Transaction(
      tipo: Transaction.tipoGasto,
      monto: 30,
      categoria: 'cafe',
      fecha: DateTime(2026, 5, 1),
      activoId: activoId,
      fechaCreacion: DateTime(2026, 5, 1),
    ));

    await repo.delete(activoId);

    expect(await filas(Asset.tableName), isEmpty);
    expect(await filas(PresupuestoActivo.tableName), isEmpty,
        reason: 'el presupuesto del mes se elimina con su cuenta');

    final abonos = await filas(AbonoMeta.tableName);
    expect(abonos, hasLength(1), reason: 'el abono conserva su historia');
    expect(abonos.single['activo_id'], isNull);

    final gastos = await filas(GastoFijo.tableName);
    expect(gastos.single['activo_id'], isNull);

    final prestamos = await filas(Loan.tableName);
    expect(prestamos.single['activo_id'], isNull);

    final inversiones = await filas(Investment.tableName);
    expect(inversiones.single['activo_id'], isNull);

    final inversionMovs = await filas(InversionMovimiento.tableName);
    expect(inversionMovs.single['activo_id'], isNull);

    final movs = await filas(Transaction.tableName);
    expect(movs, hasLength(1),
        reason: 'los movimientos son historia: ni se borran ni se tocan');
    expect(movs.single['activo_id'], activoId,
        reason: 'la referencia de la historia queda intacta');
  });
}