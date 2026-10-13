import 'dart:io';

import 'package:fitki/data/db/db_helper.dart';
import 'package:fitki/data/models/abono_meta.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/categoria_personalizada.dart';
import 'package:fitki/data/models/debt.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/gasto_fijo.dart';
import 'package:fitki/data/models/inversion_movimiento.dart';
import 'package:fitki/data/models/investment.dart';
import 'package:fitki/data/models/loan.dart';
import 'package:fitki/data/models/pago_gasto_fijo.dart';
import 'package:fitki/data/models/perfil.dart';
import 'package:fitki/data/models/presupuesto_activo.dart';
import 'package:fitki/data/models/quote.dart';
import 'package:fitki/data/models/quote_item.dart';
import 'package:fitki/data/models/quote_project.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

/// Migración v16 → v17: los movimientos guardados como 'otro' + nota se
/// convierten en categorías personalizadas reales.
///
/// La prueba construye una base real en disco con el esquema de la v16, siembra
/// movimientos 'otro' (con y sin nota) y luego la reabre con `DbHelper`, que
/// ejecuta la migración. Protege que: se creen las categorías nuevas, se
/// reutilicen las fijas y las existentes, no se dupliquen nombres dentro de la
/// misma corrida, y que las filas sin nombre queden intactas.
void main() {
  late Directory dir;
  late String ruta;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dir = Directory.systemTemp.createTempSync('fitki_migracion_otro');
    ruta = join(dir.path, 'fitki.db');
  });

  tearDownAll(() async {
    await DbHelper().close();
    DbHelper.rutaParaTests = null;
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> sembrarVersion16() async {
    final db = await databaseFactory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 16,
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final sql in [
            Asset.createTableSQL,
            Transaction.createTableSQL,
            FinancialGoal.createTableSQL,
            AbonoMeta.createTableSQL,
            Loan.createTableSQL,
            Investment.createTableSQL,
            InversionMovimiento.createTableSQL,
            Debt.createTableSQL,
            QuoteProject.createTableSQL,
            Quote.createTableSQL,
            QuoteItem.createTableSQL,
            GastoFijo.createTableSQL,
            PagoGastoFijo.createTableSQL,
            PresupuestoActivo.createTableSQL,
            CategoriaPersonalizada.createTableSQL,
            Perfil.createTableSQL,
          ]) {
            batch.execute(sql);
          }
          await batch.commit(noResult: true);
        },
      ),
    );

    // Categoría personalizada que ya existía antes de la migración.
    await db.insert(
      CategoriaPersonalizada.tableName,
      {
        'nombre': 'Mascotas',
        'icono': 'pets_rounded',
        'tipo': 'gasto',
      },
    );

    Future<void> movimiento(String tipo, String categoria, String? nota) async {
      await db.insert(
        Transaction.tableName,
        {
          'tipo': tipo,
          'monto': 1000,
          'categoria': categoria,
          'fecha': '2026-01-01',
          'nota': nota,
          'fecha_creacion': '2026-01-01 10:00:00',
        },
      );
    }

    // La nota coincide con la personalizada existente: se reutiliza.
    await movimiento('gasto', 'otro', 'Mascotas');
    // Mismo nombre en minúsculas: también reutiliza, no duplica.
    await movimiento('gasto', 'otro', 'mascotas');
    // Mismo nombre pero de ingreso: sí es categoría nueva.
    await movimiento('ingreso', 'otro', 'Mascotas');
    // Coincide con una fija por etiqueta: pasa a su slug, sin fila nueva.
    await movimiento('gasto', 'otro', 'Transporte');
    // Nombre nuevo de gasto.
    await movimiento('gasto', 'otro', 'Gimnasio');
    // Nombre ya creado en esta misma corrida (eso tipo): no duplica.
    await movimiento('ingreso', 'otro', 'gimnasio');
    // Sin nota real: se queda como 'otro'.
    await movimiento('gasto', 'otro', null);
    await movimiento('gasto', 'otro', '   ');
    // Ajeno al caso: intacto.
    await movimiento('gasto', 'alimentacion', 'comida normal');
    // Nota idéntica al slug de una fija de ingreso.
    await movimiento('ingreso', 'otro', 'salario');

    await db.close();
  }

  Future<Map<String, String>> categoriasPorNota(Database db) async {
    final filas = await db.query(
      Transaction.tableName,
      columns: ['nota', 'categoria'],
      where: 'nota IS NOT NULL',
    );
    return {
      for (final fila in filas) fila['nota'] as String: fila['categoria'] as String,
    };
  }

  test('v16 con "otro" + nota migra a categorías personalizadas', () async {
    DbHelper.rutaParaTests = ruta;
    await sembrarVersion16();

    final helper = DbHelper();
    final db = await helper.database; // ejecuta la migración a v17

    final porNota = await categoriasPorNota(db);
    expect(await db.getVersion(), 17);
    expect(porNota['Mascotas'], 'Mascotas');
    expect(porNota['mascotas'], 'Mascotas');
    expect(porNota['Transporte'], 'transporte');
    expect(porNota['Gimnasio'], 'Gimnasio');
    expect(porNota['gimnasio'], 'gimnasio');
    expect(porNota['salario'], 'salario');
    expect(porNota['comida normal'], 'alimentacion');

    // Las notas no se tocan.
    final notaMascotas = await db.query(
      Transaction.tableName,
      columns: ['nota'],
      where: 'categoria = ?',
      whereArgs: ['Mascotas'],
      limit: 1,
    );
    expect(notaMascotas.first['nota'], 'Mascotas');

    // Los 'otro' sin nombre se quedan como 'otro'.
    final otros = await db.query(
      Transaction.tableName,
      columns: ['nota', 'categoria'],
      where: 'categoria = ?',
      whereArgs: ['otro'],
    );
    expect(otros.length, 2);

    // Categorías: la sembrada + 'Mascotas' ingreso + 'Gimnasio' gasto +
    // 'Gimnasio' ingreso (4 en total, sin duplicados).
    final categorias = await db.query(
      CategoriaPersonalizada.tableName,
      orderBy: 'tipo, nombre',
    );
    expect(categorias.length, 4);
    final porNombreTipo = {
      for (final c in categorias)
        '${c['tipo']}|${c['nombre']}': c['icono'],
    };
    expect(porNombreTipo['gasto|Mascotas'], 'pets_rounded');
    expect(porNombreTipo['ingreso|Mascotas'], 'category_rounded');
    expect(porNombreTipo['gasto|Gimnasio'], 'category_rounded');
    expect(porNombreTipo['ingreso|gimnasio'], 'category_rounded');

    // Reabrir tras cerrar no vuelve a migrar ni duplica nada.
    await helper.close();
    final db2 = await DbHelper().database;
    expect(await db2.getVersion(), 17);
    expect(await db2.query(CategoriaPersonalizada.tableName), hasLength(4));
  });
}