import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../logic/categorias/categoria_labels.dart';
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
import '../models/plan_asignacion.dart';
import '../models/detalle_asignacion.dart';
import '../models/categoria_personalizada.dart';
import '../models/perfil.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static sqflite.Database? _database;

  factory DbHelper() => _instance;

  DbHelper._internal();

  static const int _dbVersion = 20;
  static const String _dbName = 'fitki.db';

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Ruta de la base a abrir. En producción es `null` y se deriva de
  /// `getDatabasesPath()`. Los tests lo fijan a una base aislada (p. ej. en
  /// memoria) para que varios archivos de test no compitan por el mismo
  /// `fitki.db` en disco.
  static String? rutaParaTests;

  /// Ruta del archivo .db actual (la misma que usa [database] para abrir la
  /// conexión). Es útil para copiar el archivo completo (backup/restauración).
  static Future<String> getDatabasePath() async {
    final override = rutaParaTests;
    if (override != null) return override;
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
    batch.execute(PlanAsignacion.createTableSQL);
    batch.execute(DetalleAsignacion.createTableSQL);
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
      // La v9 creaba aquí `gastos_fijos` y `pagos_gastos_fijos`, más tarde
      // limpiadas por la v16 y ya inexistentes tras la v19. No se crean: un
      // modelo que solo vive entre dos migraciones no tiene sentido, y la v19
      // las volvería a borrar de todas formas.
      // Aquí la v9 creaba el presupuesto por activo. Ese modelo ya no existe:
      // la v18 descarta esa tabla y en su lugar crea el presupuesto por
      // categoría. No se recrea porque una base que llegue hasta la versión
      // actual nunca la necesita.
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
    if (oldVersion < 15) {
      // `items_cotizacion.tipo` se añadió en la v7, pero el CREATE TABLE que
      // usa `_onCreate` nunca lo incluyó: una instalación nueva (que nace
      // directo en la versión actual y no ejecuta migraciones) creaba la tabla
      // sin la columna, y guardar un item fallaba con "no such column: tipo",
      // que la pantalla traducía como "No se pudo guardar, intenta de nuevo".
      //
      // El esquema inicial ya está corregido, así que esta migración solo
      // repara las bases que nacieron rotas. Se comprueba antes de añadirla
      // porque una base que sí pasó por la v7 ya la tiene, y repetir el
      // ALTER abortaría la migración con "duplicate column name".
      final columnasItem = await db.rawQuery(
        'PRAGMA table_info(${QuoteItem.tableName})',
      );
      final yaTieneTipo = columnasItem.any(
        (columna) => columna['name'] == 'tipo',
      );
      if (!yaTieneTipo) {
        await db.execute(
          "ALTER TABLE ${QuoteItem.tableName} "
          "ADD COLUMN tipo TEXT NOT NULL DEFAULT '${QuoteItem.tipoProducto}'",
        );
      }
    }
    if (oldVersion < 16) {
      // El borrado de una cuenta se hacía a mano (las claves foráneas están
      // desactivadas) y dejó fuera `abonos_metas`, `inversiones` e
      // `inversiones_movimientos`: sus filas podían quedar apuntando a una
      // cuenta que ya no existe. Esta migración solo repara esos huérfanos
      // dejando el enlace en NULL — no borra ninguna fila, porque son parte
      // del historial del dinero. Los movimientos se excluyen a propósito: su
      // `activo_id` no se toca por diseño ("los movimientos nunca se tocan,
      // son el historial").
      for (final tabla in [
        AbonoMeta.tableName,
        InversionMovimiento.tableName,
        Investment.tableName,
        Loan.tableName,
      ]) {
        await db.execute('''
          UPDATE $tabla SET activo_id = NULL
          WHERE activo_id IS NOT NULL
            AND activo_id NOT IN (SELECT id FROM ${Asset.tableName})
        ''');
      }
    }
    if (oldVersion < 17) {
      // Antes, elegir "Otro" en un movimiento guardaba el slug 'otro' y el
      // nombre que el usuario escribía quedaba atrapado en la nota, invisible
      // como categoría. Esta migración crea esas categorías personalizadas
      // (una por nombre y tipo únicos) y reasigna cada movimiento a la suya.
      // Si el texto coincide con una fija o con una personalizada existente se
      // reutiliza la existente sin crear filas nuevas. Los movimientos con
      // 'otro' sin nota real quedan intactos; la nota y el resto del historial
      // nunca se tocan.
      await _migrarOtroACategorias(db);
    }
    if (oldVersion < 18) {
      // El presupuesto deja de ser un límite por cuenta: la tabla vieja se
      // descarta porque un límite por cuenta no se puede convertir en límites
      // por categoría (son conceptos distintos). La tabla que esta migración
      // creaba (`presupuestos_categoria`) se borró a su vez en la v20 con el
      // módulo completo, así que una base que suba desde acá termina sin
      // ninguna tabla de presupuesto. Los movimientos, que son el historial
      // real del dinero, nunca se tocan. El nombre va como texto literal a
      // propósito: el modelo PresupuestoActivo ya no existe en el código, pero
      // una base vieja sí tiene esa tabla.
      await db.execute('DROP TABLE IF EXISTS presupuestos_activo');
    }
    if (oldVersion < 19) {
      // Módulo AFCA: los planes de asignación sustituyen al presupuesto rígido
      // por mes. Un plan se ata a un activo y reparte un monto entre categorías
      // (bolsillos) sin fechas. Los detalles no guardan lo gastado: se deriva de
      // los movimientos vinculados por `plan_detalle_id`.
      //
      // La columna se añade aquí y no solo en el esquema inicial porque una base
      // que venga de la v18 no la tiene. Se comprueba con PRAGMA antes de
      // agregarla para no abortar con "duplicate column name" en una base que
      // nació directo en la versión actual.
      //
      // El módulo de Gastos Fijos desaparece: la v19 borra sus tablas. Los pagos
      // ya confirmados quedaron como movimientos en `movimientos`, que es el
      // historial real y no se toca. Los nombres van como texto literal: sus
      // modelos ya no existen en el código, pero una base vieja sí tiene esas
      // tablas.
      for (final tabla in ['gastos_fijos', 'pagos_gastos_fijos']) {
        await db.execute('DROP TABLE IF EXISTS $tabla');
      }
      await db.execute(PlanAsignacion.createTableSQL);
      await db.execute(DetalleAsignacion.createTableSQL);
      final columnasMov = await db.rawQuery(
        'PRAGMA table_info(${Transaction.tableName})',
      );
      final yaTieneDetalle = columnasMov.any(
        (columna) => columna['name'] == 'plan_detalle_id',
      );
      if (!yaTieneDetalle) {
        await db.execute(
          'ALTER TABLE ${Transaction.tableName} ADD COLUMN plan_detalle_id INTEGER',
        );
      }
    }
    if (oldVersion < 20) {
      // Fin del presupuesto mensual: AFCA (v19) ya cubre la asignación del
      // dinero y no conviven los dos controles en la misma app. Se borra la
      // tabla de topes por categoría sin migrar sus cifras: los topes son
      // datos de configuración, no historial, y los planes de AFCA se arman a
      // mano. Los movimientos y los planes creados desde la v19 no se tocan.
      await db.execute('DROP TABLE IF EXISTS presupuestos_categoria');
    }
  }

  /// Migración a la v17: convierte los movimientos guardados como 'otro' + nota
  /// en categorías personalizadas reales. Comparte la lógica de coincidencia
  /// con los formularios, para que una categoría que ya existía o que coincide
  /// con una fija no se cree dos veces.
  Future<void> _migrarOtroACategorias(sqflite.Database db) async {
    final candidatos = await db.rawQuery(
      'SELECT id, tipo, nota FROM ${Transaction.tableName} '
      "WHERE categoria = 'otro'",
    );
    final conNombre = candidatos
        .where((fila) {
          final nota = fila['nota'] as String?;
          final tipo = fila['tipo'] as String?;
          return nota != null &&
              nota.trim().isNotEmpty &&
              (tipo == Transaction.tipoGasto ||
                  tipo == Transaction.tipoIngreso);
        })
        .toList();
    if (conNombre.isEmpty) return;

    final existentes = (await db
            .query(CategoriaPersonalizada.tableName))
        .map(CategoriaPersonalizada.fromMap)
        .toList();
    // Nombres creados durante esta misma corrida: dos movimientos pueden usar
    // la misma categoría nueva y no debe insertarse dos veces.
    final creadas = <String>{};

    for (final fila in conNombre) {
      final id = fila['id'] as int;
      final nota = (fila['nota'] as String).trim();
      final tipo = fila['tipo'] as String;

      final existente = categoriaCoincidenteDeNombre(
        nombre: nota,
        tipo: tipo,
        existentes: existentes,
      );
      final clave = '$tipo|${nota.toLowerCase()}';
      if (existente == null && !creadas.contains(clave)) {
        await db.insert(
          CategoriaPersonalizada.tableName,
          CategoriaPersonalizada(
            nombre: nota,
            icono: 'category_rounded',
            tipo: tipo,
          ).toMap(),
        );
        creadas.add(clave);
      }
      await db.update(
        Transaction.tableName,
        {'categoria': existente ?? nota},
        where: 'id = ?',
        whereArgs: [id],
      );
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
  ///
  /// Además reinicia los contadores AUTOINCREMENT (los ids vuelven a empezar
  /// en 1) y compacta el archivo con `VACUUM`. Los comprobantes adjuntos son
  /// archivos fuera de la base y se eliminan aparte (ver `borrarTodosLosDatos`).
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
      PlanAsignacion.tableName,
      DetalleAsignacion.tableName,
      CategoriaPersonalizada.tableName,
      Perfil.tableName,
    ]) {
      batch.execute('DELETE FROM $tabla');
    }
    // `sqlite_sequence` solo existe si alguna tabla AUTOINCREMENT recibió al
    // menos una fila; si nunca se insertó nada, no hay contadores que reiniciar.
    final haySecuencia = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'sqlite_sequence'",
    );
    if (haySecuencia.isNotEmpty) {
      batch.execute('DELETE FROM sqlite_sequence');
    }
    await batch.commit(noResult: true);
    // `VACUUM` recupera el espacio y reescribe el archivo compacto; debe
    // correr fuera de la transacción del batch (SQLite no lo permite dentro).
    await db.execute('VACUUM');
  }
}