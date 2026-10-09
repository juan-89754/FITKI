import 'package:fitki/data/models/quote_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests de regresión del guardado de items de cotización.
///
/// El bug original: `items_cotizacion` se creaba (en instalaciones nuevas) sin
/// la columna `tipo`, pero `QuoteItem.toMap()` siempre la escribe. Guardar un
/// item lanzaba `no such column: tipo`, que la pantalla mostraba como
/// "No se pudo guardar, intenta de nuevo". Estos tests crean la tabla con el
/// mismo SQL que usa `_onCreate`, es decir, como una instalación recién hecha.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> baseNueva() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(QuoteItem.createTableSQL);
    return db;
  }

  QuoteItem itemDeEjemplo({
    String tipo = QuoteItem.tipoProducto,
    int? id,
  }) {
    return QuoteItem(
      id: id,
      cotizacionId: 1,
      productoServicio: 'Diseño de logo',
      tipo: tipo,
      cantidad: 2,
      precioUnitario: 50000,
    );
  }

  group('items_cotizacion', () {
    test('la tabla declara todas las columnas que toMap escribe', () async {
      final db = await baseNueva();
      addTearDown(db.close);

      final columnas = (await db.rawQuery(
        'PRAGMA table_info(${QuoteItem.tableName})',
      ))
          .map((fila) => fila['name'] as String)
          .toSet();

      for (final columna in itemDeEjemplo().toMap().keys) {
        expect(
          columnas,
          contains(columna),
          reason: 'toMap() escribe "$columna" pero la tabla no la tiene',
        );
      }
    });

    test('guarda un item en una base recién creada y lo lee de vuelta',
        () async {
      final db = await baseNueva();
      addTearDown(db.close);

      final id = await db.insert(
        QuoteItem.tableName,
        itemDeEjemplo(tipo: QuoteItem.tipoServicio).toMap(),
      );

      final filas = await db.query(
        QuoteItem.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      final guardado = QuoteItem.fromMap(filas.single);

      expect(guardado.productoServicio, 'Diseño de logo');
      expect(guardado.tipo, QuoteItem.tipoServicio);
      expect(guardado.cantidad, 2);
      expect(guardado.precioUnitario, 50000);
    });
  });
}
