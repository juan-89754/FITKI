import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../data/db/db_helper.dart';
import '../../data/storage/comprobante_storage.dart';

/// Backups de Fitki: la app usa una sola base de datos sqflite, pero los
/// comprobantes adjuntos viven como archivos sueltos en disco. Para que un
/// movimiento restaurado no quede apuntando a un adjunto inexistente, el
/// respaldo es un `.zip` con la base (`fitki.db`) y la carpeta de comprobantes
/// adentro. Los backups antiguos (un `.db` suelto, sin adjuntos) también se
/// siguen restaurando.
///
/// Esta capa es lógica pura: no depende de Riverpod. La invalidación de los
/// providers de datos (para que la UI se recargue) la dispara la pantalla
/// mediante el callback [onRestaurado].
///
/// GARANTÍA DE INTEGRIDAD AL RESTAURAR:
///  - Se valida ANTES de tocar la base real que el `.db` elegido (suelto o
///    extraído del `.zip`) tenga el esquema de Fitki (consulta a sqlite_master
///    en modo solo lectura, conexión aparte). Un archivo que no lo cumpla se
///    rechaza sin modificar nada. La validación previa exige el núcleo de
///    tablas (las que tiene cualquier backup de Fitki, por antiguo que sea);
///    las que agrega una versión nueva se exigen sobre la base ya migrada, y la
///    migración se encarga de crearlas.
///  - Durante el reemplazo se conserva una copia de la base actual (y de la
///    carpeta de comprobantes, cuando el backup trae adjuntos) en ubicaciones
///    temporales. Ante cualquier fallo a mitad de camino (copias, reapertura o
///    verificación posterior) se REVIERTE la base real y los comprobantes desde
///    esas copias (o se elimina lo reemplazado si no había nada previo) y se
///    deja la app operativa con los datos originales.
class RestauracionRevertidaException implements Exception {
  const RestauracionRevertidaException();

  /// Mensaje claro para la UI: los datos originales sobrevivieron al fallo.
  static const String mensajeUsuario =
      'No se pudo restaurar, tus datos originales se mantuvieron a salvo';

  @override
  String toString() => mensajeUsuario;
}

/// Nombre del archivo de base dentro del `.zip` de backup (en la raíz).
const String _nombreDbEnZip = 'fitki.db';

/// Carpeta de comprobantes dentro del `.zip` de backup.
const String _carpetaComprobantes = 'comprobantes';

/// Tablas que ya existían antes de que la app empezara a agregar tablas nuevas.
/// Un archivo solo se acepta como backup de Fitki si trae TODAS estas: son las
/// que identifican el esquema y las que un backup antiguo también tiene.
///
/// El presupuesto mensual queda afuera a propósito: cambió de tabla entre
/// versiones (`presupuestos_activo` hasta la v17, `presupuestos_categoria`
/// desde la v18) y la v20 lo eliminó junto con su módulo, así que no hay una
/// tabla que tengan TODOS los backups y una base nueva ni la crea. Los backups
/// viejos sí la traen, pero como solo se exige el núcleo vigente siguen
/// pasando la validación.
///
/// El módulo de Gastos Fijos (`gastos_fijos`, `pagos_gastos_fijos`) siguió la
/// misma trayectoria en la v19.
///
/// Las tablas de [_tablasAgregadas] NO se exigen en el archivo, porque un backup
/// tomado antes de que existieran válidamente no las trae. Se crean solas al
/// reabrir la base restaurada, que es cuando corren las migraciones; por eso
/// [_esquemaCompletoYLegible], que sí se ejecuta sobre la base ya migrada, exige
/// el conjunto completo.
const Set<String> _tablasNucleo = {
  'activos',
  'movimientos',
  'metas_financieras',
  'prestamos',
  'inversiones',
  'deudas',
  'proyectos_cotizacion',
  'cotizaciones',
  'items_cotizacion',
  'categorias_personalizadas',
  'perfil',
};

/// Tablas que las migraciones de `DbHelper._onUpgrade` crean por encima del
/// núcleo. Mantener en sincronía con `_onCreate`/`_onUpgrade` de db_helper.dart.
const Set<String> _tablasAgregadas = {
  'abonos_metas',
  'inversiones_movimientos',
  'planes_asignacion',
  'detalles_asignacion',
};

/// Todas las tablas que [DbHelper] crea al inicializar.
const Set<String> _tablasFitki = {..._tablasNucleo, ..._tablasAgregadas};

/// Empaqueta el estado actual de Fitki en un `.zip` (`fitki.db` + la carpeta
/// `comprobantes/`) en un archivo temporal del dispositivo con nombre
/// `fitki_backup_YYYY-MM-DD_HHmm.zip` y devuelve la ruta del archivo generado.
Future<String> generarBackup() async {
  final rutaDb = await DbHelper.getDatabasePath();
  final archivoDb = File(rutaDb);
  if (!archivoDb.existsSync()) {
    throw FileSystemException('No se encontró la base de datos actual', rutaDb);
  }

  final archivo = Archive();
  archivo.add(ArchiveFile.bytes(_nombreDbEnZip, await archivoDb.readAsBytes()));

  // Los comprobantes son archivos sueltos: si no viajan en el backup, un
  // movimiento restaurado apuntaría a un adjunto inexistente.
  final dirComprobantes = await ComprobanteStorage().directorio();
  if (await dirComprobantes.exists()) {
    await for (final entidad in dirComprobantes.list()) {
      if (entidad is! File) continue;
      archivo.add(ArchiveFile.bytes(
        '$_carpetaComprobantes/${p.basename(entidad.path)}',
        await entidad.readAsBytes(),
      ));
    }
  }

  final dirTemp = await getTemporaryDirectory();
  final nombre = 'fitki_backup_'
      '${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}'
      '.zip';
  final destino = p.join(dirTemp.path, nombre);

  await File(destino).writeAsBytes(ZipEncoder().encodeBytes(archivo), flush: true);
  return destino;
}

/// Restaura los datos de Fitki desde el archivo elegido (un `.zip` de Fitki o
/// un `.db` antiguo), con la máxima salvaguarda posible: la base real solo se
/// reemplaza si el `.db` pasa la validación de esquema, y si algo falla durante
/// la restauración se revierten la base y los comprobantes desde copias
/// temporales tomadas al inicio.
///
/// Lanza [FileSystemException] si el archivo elegido no existe,
/// [FormatException] si no es un backup válido de Fitki (zip ilegible o tablas
/// incompletas) y [RestauracionRevertidaException] si la restauración falla a
/// mitad de camino y el estado original fue restaurado.
Future<void> restaurarBackup(
  String rutaArchivoElegido, {
  void Function()? onRestaurado,
}) async {
  final origen = File(rutaArchivoElegido);
  if (!origen.existsSync()) {
    throw FileSystemException('El archivo elegido no existe', rutaArchivoElegido);
  }

  // Prepara el origen: un .db suelto (backup antiguo) o el .db y los
  // comprobantes extraídos de un .zip a un directorio temporal.
  final preparado = await _prepararOrigen(rutaArchivoElegido);
  try {
    // 1) Validación de esquema ANTES de tocar la base real. Se abre el .db
    //    elegido en SOLO LECTURA (conexión aparte) y se comprueba contra
    //    sqlite_master que estén todas las tablas del núcleo de Fitki.
    if (!await _esBackupFitkiValido(preparado.rutaDb)) {
      throw const FormatException('Este archivo no es un backup válido de Fitki');
    }
    await _reemplazarEstado(preparado, onRestaurado: onRestaurado);
  } finally {
    await _limpiarStaging(preparado.staging);
  }
}

/// Reemplaza la base real (y, si el backup los trae, los comprobantes) por lo
/// indicado en [preparado], revirtiendo ante cualquier fallo.
Future<void> _reemplazarEstado(
  _BackupPreparado preparado, {
  void Function()? onRestaurado,
}) async {
  final db = DbHelper();
  final archivoDb = File(await DbHelper.getDatabasePath());
  final existiaBase = archivoDb.existsSync();
  final dirTemp = await getTemporaryDirectory();
  final respaldo = File(p.join(dirTemp.path, 'fitki_antes_de_restaurar.db'));

  final comprobantesActuales = await ComprobanteStorage().directorio();
  final reemplazaComprobantes = preparado.comprobantes != null;
  final existianComprobantes = reemplazaComprobantes &&
      (await comprobantesActuales.exists()) &&
      (await comprobantesActuales.list().toList()).isNotEmpty;
  final respaldoComprobantes =
      Directory(p.join(dirTemp.path, 'fitki_comprobantes_antes'));

  // Se cierra la conexión actual y se olvida la referencia para poder
  // reemplazar el archivo y reabrirlo. La base real solo se muta a partir de
  // aquí; cualquier fallo posterior detona la reversión.
  await db.close();

  try {
    // a) Copia de seguridad de lo actual (solo lo que existe).
    if (existiaBase) {
      await archivoDb.copy(respaldo.path);
    }
    if (existianComprobantes) {
      await _copiarDirectorio(comprobantesActuales, respaldoComprobantes);
    }

    // b) Reemplazo del archivo real por el elegido.
    await File(preparado.rutaDb).copy(archivoDb.path);
    _borrarArchivosHermanos(archivoDb.path);

    // c) Reemplazo de los comprobantes, si el backup los trae.
    if (reemplazaComprobantes) {
      await _reemplazarDirectorio(preparado.comprobantes!, comprobantesActuales);
    }

    // d) Reapertura y verificación funcional de la base ya reemplazada (las
    //    migraciones de esquema se aplican al abrirla).
    final conexion = await db.database;
    if (await _esquemaCompletoYLegible(conexion)) {
      // e) Éxito: se eliminan las copias temporales.
      _eliminarSiExiste(respaldo);
      _eliminarDirectorio(respaldoComprobantes);
      onRestaurado?.call();
      return;
    }
    // Si la base reemplazada no quedó completa/legible, se cae a la reversión.
  } catch (_) {
    // Cualquier fallo de las copias, la reapertura o la verificación (permisos,
    // espacio, base ilegible…) conduce a la reversión.
  }

  // f) Reversión automática: base y comprobantes vuelven a su estado original.
  await _revertir(
    db,
    archivoDb,
    respaldo,
    existiaBase: existiaBase,
    comprobantesActuales: comprobantesActuales,
    respaldoComprobantes: respaldoComprobantes,
    existianComprobantes: existianComprobantes,
    reemplazaComprobantes: reemplazaComprobantes,
  );
  throw const RestauracionRevertidaException();
}

/// Revierte la base real (y los comprobantes, si el backup los había
/// reemplazado) a su estado previo a la restauración. Si existía base, se
/// vuelve a copiar [respaldo] sobre la ruta real, se descartan
/// journals/checkpoints huérfanos del archivo reemplazado y se reabre la
/// conexión para que la app quede operativa con los datos originales. Si no
/// existía base ([existiaBase] false), se elimina el archivo reemplazado para
/// que la app regrese al estado inicial (onCreate en el próximo acceso).
///
/// Es best-effort: si [respaldo] nunca llegó a crearse (la base real no se
/// tocó) no hay nada que deshacer, y el respaldo se conserva en disco ante un
/// fallo del propio revert para permitir recuperación manual.
Future<void> _revertir(
  DbHelper db,
  File archivoDb,
  File respaldo, {
  required bool existiaBase,
  required Directory comprobantesActuales,
  required Directory respaldoComprobantes,
  required bool existianComprobantes,
  required bool reemplazaComprobantes,
}) async {
  try {
    // Libera la conexión sobre el archivo reemplazado/roto antes de tocarlo.
    await db.close();
  } catch (_) {
    // La conexión puede estar ya cerrada o en uso; se continúa igual.
  }

  // Comprobantes: vuelven a su estado previo si el backup los reemplazó.
  if (reemplazaComprobantes) {
    try {
      if (existianComprobantes && await respaldoComprobantes.exists()) {
        await _reemplazarDirectorio(respaldoComprobantes, comprobantesActuales);
      } else if (!existianComprobantes && await comprobantesActuales.exists()) {
        await comprobantesActuales.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort: si no se pudo revertir, los adjuntos del backup quedan;
      // la base sí se revierte abajo.
    }
  }

  if (!existiaBase) {
    try {
      archivoDb.deleteSync();
      _borrarArchivosHermanos(archivoDb.path);
    } catch (_) {
      // Si no se pudo eliminar, el próximo arranque decide sobre ese archivo.
    }
    return;
  }

  if (!respaldo.existsSync()) return;

  try {
    await respaldo.copy(archivoDb.path);
    _borrarArchivosHermanos(archivoDb.path);
    // Reabre la base original y deja la app operativa (los streams se
    // recuperan solos en su próxima consulta).
    await db.database;
  } catch (_) {
    // La reapertura tras revertir es best-effort: el archivo ya quedó
    // reemplazado por el original y la conexión se reintentará.
  }
}

/// Prepara el material a restaurar. Para un `.db` suelto (backup antiguo)
/// devuelve esa misma ruta y ningún comprobante. Para un `.zip` extrae el
/// `fitki.db` y la carpeta `comprobantes/` a un directorio temporal y devuelve
/// sus rutas. Lanza [FormatException] si el `.zip` no se puede leer o no trae
/// una base.
Future<_BackupPreparado> _prepararOrigen(String rutaElegida) async {
  if (p.extension(rutaElegida).toLowerCase() != '.zip') {
    return _BackupPreparado(rutaDb: rutaElegida);
  }

  final staging = Directory(
    p.join((await getTemporaryDirectory()).path, 'fitki_restore'),
  );
  if (await staging.exists()) {
    await staging.delete(recursive: true);
  }
  await staging.create(recursive: true);

  Archive archivo;
  try {
    archivo = ZipDecoder().decodeBytes(await File(rutaElegida).readAsBytes());
  } catch (_) {
    await _limpiarStaging(staging);
    throw const FormatException('Este archivo no es un backup válido de Fitki');
  }

  File? dbExtraida;
  Directory? dirComprobantes;
  for (final entrada in archivo) {
    if (!entrada.isFile) continue;
    final nombre = entrada.name.replaceAll('\\', '/');
    final base = p.basename(nombre);
    final datos = entrada.readBytes();
    if (datos == null) continue;

    if (dbExtraida == null && base.toLowerCase().endsWith('.db')) {
      dbExtraida = File(p.join(staging.path, 'elegida.db'));
      await dbExtraida.writeAsBytes(datos, flush: true);
    } else if (nombre.startsWith('$_carpetaComprobantes/')) {
      dirComprobantes ??= Directory(p.join(staging.path, _carpetaComprobantes))
        ..createSync(recursive: true);
      await File(p.join(dirComprobantes.path, base))
          .writeAsBytes(datos, flush: true);
    }
  }

  if (dbExtraida == null) {
    await _limpiarStaging(staging);
    throw const FormatException('Este archivo no es un backup válido de Fitki');
  }

  return _BackupPreparado(
    rutaDb: dbExtraida.path,
    comprobantes: dirComprobantes,
    staging: staging,
  );
}

/// Copia los archivos de [origen] sobre [destino] (creándolo si hace falta) sin
/// borrar lo que ya hubiera allí.
Future<void> _copiarDirectorio(Directory origen, Directory destino) async {
  if (!await destino.exists()) {
    await destino.create(recursive: true);
  }
  await for (final entidad in origen.list()) {
    if (entidad is File) {
      await entidad.copy(p.join(destino.path, p.basename(entidad.path)));
    }
  }
}

/// Deja [destino] con exactamente los archivos de [origen]: lo vacía primero.
Future<void> _reemplazarDirectorio(Directory origen, Directory destino) async {
  if (await destino.exists()) {
    await destino.delete(recursive: true);
  }
  await _copiarDirectorio(origen, destino);
}

/// Abre el archivo en modo solo lectura y verifica que contenga TODAS las
/// tablas de Fitki. Devuelve false ante cualquier error de apertura/consulta
/// o si falta alguna tabla, sin tocar la base actual.
Future<bool> _esBackupFitkiValido(String ruta) async {
  sqflite.Database? conexion;
  try {
    // Apertura en modo solo lectura: la conexión de validación NUNCA escribe
    // y no registra versiones ni corridas de onCreate/onUpgrade.
    conexion = await sqflite.openReadOnlyDatabase(
      ruta,
      singleInstance: false,
    );
    return await _esquemaCompleto(conexion);
  } catch (_) {
    return false;
  } finally {
    try {
      await conexion?.close();
    } catch (_) {
      // La conexión de validación es desechable.
    }
  }
}

/// Comprueba que la conexión tenga las tablas del núcleo de Fitki. Es la
/// validación que se hace sobre el archivo ELEGIDO tal como está, sin migrarlo:
/// por eso exige solo el núcleo y no las tablas que las migraciones crean.
Future<bool> _esquemaCompleto(sqflite.Database db) async {
  return await _tieneTablas(db, _tablasNucleo);
}

/// Igual que [_esquemaCompleto] pero sobre la base ya reabierta y migrada: ahí
/// sí tienen que estar todas las tablas, incluidas las que agrega una versión
/// posterior de la app, porque las migraciones debieron crearlas. Además ejecuta
/// una consulta de lectura real sobre la tabla más liviana del esquema (perfil,
/// presente en cualquier backup de Fitki) para confirmar que la base
/// reemplazada no solo tiene el esquema sino que además es legible.
Future<bool> _esquemaCompletoYLegible(sqflite.Database db) async {
  try {
    if (!await _tieneTablas(db, _tablasFitki)) return false;
    await db.rawQuery('SELECT COUNT(*) AS total FROM perfil');
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> _tieneTablas(
  sqflite.Database db,
  Set<String> requeridas,
) async {
  final filas = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  final presentes = filas
      .map((fila) => fila['name'] as String?)
      .whereType<String>()
      .toSet();
  return requeridas.every(presentes.contains);
}

/// Elimina los journals/checkpoints hermanos de [rutaBase] (restos de
/// transacciones de una base anterior que corromperían la lectura de una
/// reemplazada). Best-effort.
void _borrarArchivosHermanos(String rutaBase) {
  for (final sufijo in ['-wal', '-shm', '-journal']) {
    final extra = File('$rutaBase$sufijo');
    if (extra.existsSync()) {
      try {
        extra.deleteSync();
      } catch (_) {
        // Un journal atascado se descarta con el siguiente arranque.
      }
    }
  }
}

void _eliminarSiExiste(File archivo) {
  try {
    if (archivo.existsSync()) archivo.deleteSync();
  } catch (_) {
    // Limpieza best-effort de un temporal.
  }
}

void _eliminarDirectorio(Directory dir) {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {
    // Limpieza best-effort de un temporal.
  }
}

Future<void> _limpiarStaging(Directory? staging) async {
  if (staging == null) return;
  _eliminarDirectorio(staging);
}

/// Material ya preparado a partir del archivo elegido: la ruta del `.db` a
/// validar/restaurar, el directorio temporal con los comprobantes (null si el
/// backup no trae adjuntos, p. ej. un `.db` antiguo) y el directorio temporal a
/// limpiar al terminar (null cuando el origen es el propio `.db` elegido).
class _BackupPreparado {
  final String rutaDb;
  final Directory? comprobantes;
  final Directory? staging;

  const _BackupPreparado({
    required this.rutaDb,
    this.comprobantes,
    this.staging,
  });
}
