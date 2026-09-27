import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../data/db/db_helper.dart';

/// Backups de Fitki: la app usa una sola base de datos sqflite, así que la
/// forma más simple y confiable de respaldar/restaurar es copiar el archivo
/// .db completo (no exportar tabla por tabla).
///
/// Esta capa es lógica pura: no depende de Riverpod. La invalidación de los
/// providers de datos (para que la UI se recargue) la dispara la pantalla
/// mediante el callback [onRestaurado].
///
/// GARANTÍA DE INTEGRIDAD AL RESTAURAR:
///  - Se valida ANTES de tocar la base real que el archivo elegido tenga
///    TODAS las tablas de Fitki (consulta a sqlite_master en modo solo
///    lectura, conexión aparte). Un archivo que no lo cumpla se rechaza sin
///    modificar nada.
///  - Durante el reemplazo se conserva una copia de la base actual en un
///    archivo temporal. Ante cualquier fallo a mitad de camino (copias,
///    reapertura o verificación posterior) se REVIERTE la base real desde esa
///    copia (o se elimina el archivo reemplazado si no existía base previa) y
///    se deja la app operativa con los datos originales.
class RestauracionRevertidaException implements Exception {
  const RestauracionRevertidaException();

  /// Mensaje claro para la UI: los datos originales sobrevivieron al fallo.
  static const String mensajeUsuario =
      'No se pudo restaurar, tus datos originales se mantuvieron a salvo';

  @override
  String toString() => mensajeUsuario;
}

/// Todas las tablas que crea [DbHelper] al inicializar. Mantener en
/// sincronía con `_onCreate`/`_onUpgrade` de db_helper.dart.
const Set<String> _tablasFitki = {
  'activos',
  'movimientos',
  'metas_financieras',
  'prestamos',
  'inversiones',
  'deudas',
  'proyectos_cotizacion',
  'cotizaciones',
  'items_cotizacion',
  'gastos_fijos',
  'pagos_gastos_fijos',
  'presupuestos_activo',
  'categorias_personalizadas',
  'perfil',
};

/// Copia el archivo .db actual (la misma ruta que usa [DbHelper]) a un
/// archivo temporal del dispositivo con nombre
/// `fitki_backup_YYYY-MM-DD_HHmm.db` y devuelve la ruta del archivo copiado.
Future<String> generarBackup() async {
  final rutaDb = await DbHelper.getDatabasePath();
  final archivoDb = File(rutaDb);
  if (!archivoDb.existsSync()) {
    throw FileSystemException('No se encontró la base de datos actual', rutaDb);
  }

  final dirTemp = await getTemporaryDirectory();
  final nombre = 'fitki_backup_'
      '${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}'
      '.db';
  final destino = p.join(dirTemp.path, nombre);

  await archivoDb.copy(destino);
  return destino;
}

/// Restaura los datos de Fitki desde el archivo elegido, con la máxima
/// salvaguarda posible: el archivo real solo se reemplaza si el elegido pasa
/// la validación de esquema, y si algo falla durante la restauración se
/// revierte la base desde un respaldo temporal tomado al inicio.
///
/// Lanza [FileSystemException] si el archivo elegido no existe,
/// [FormatException] si no es un backup válido de Fitki (tablas incompletas)
/// y [RestauracionRevertidaException] si la restauración falla a mitad de
/// camino y la base original fue restaurada.
Future<void> restaurarBackup(
  String rutaArchivoElegido, {
  void Function()? onRestaurado,
}) async {
  final origen = File(rutaArchivoElegido);
  if (!origen.existsSync()) {
    throw FileSystemException('El archivo elegido no existe', rutaArchivoElegido);
  }

  // 1) Validación de esquema ANTES de tocar la base real. Se abre el archivo
  //    elegido en SOLO LECTURA (conexión aparte) y se comprueba contra
  //    sqlite_master que estén todas las tablas esperadas de Fitki.
  if (!await _esBackupFitkiValido(rutaArchivoElegido)) {
    throw const FormatException('Este archivo no es un backup válido de Fitki');
  }

  final db = DbHelper();
  final archivoDb = File(await DbHelper.getDatabasePath());
  // Indica si ya había base previa: si no, no hay respaldo que tomar y el
  // revert del paso d vuelve al "estado inicial" (sin archivo .db).
  final existiaBase = archivoDb.existsSync();
  final dirTemp = await getTemporaryDirectory();
  // a) El respaldo temporal de la base ACTUAL es el ancla de la reversión:
  //    si algo falla después del reemplazo, se recupera desde aquí.
  final respaldo = File(p.join(dirTemp.path, 'fitki_antes_de_restaurar.db'));

  // Se cierra la conexión actual y se olvida la referencia para poder
  // reemplazar el archivo y reabrirlo. La base real solo se muta a partir de
  // aquí; cualquier fallo posterior detona la reversión (paso d).
  await db.close();

  try {
    // a) Copia de seguridad de los datos actuales (solo si existían).
    if (existiaBase) {
      await archivoDb.copy(respaldo.path);
    }

    // b) Reemplazo del archivo real por el elegido.
    await origen.copy(archivoDb.path);
    _borrarArchivosHermanos(archivoDb.path);

    // c) Reapertura y verificación funcional de la base ya reemplazada (las
    //    migraciones de esquema se aplican al abrirla).
    final conexion = await db.database;
    if (await _esquemaCompletoYLegible(conexion)) {
      // e) Éxito: se elimina el respaldo temporal.
      _eliminarSiExiste(respaldo);
      onRestaurado?.call();
      return;
    }
    // Si la base reemplazada no quedó completa/legible, se cae a la
    // reversión común de abajo (paso d).
  } catch (_) {
    // 3) Cualquier fallo de las copias, la reapertura o la verificación
    //    (permisos, espacio, base ilegible…) conduce a la reversión.
  }

  // d) Reversión automática: la base real vuelve a su estado original.
  await _revertir(db, archivoDb, respaldo, existiaBase: existiaBase);
  throw const RestauracionRevertidaException();
}

/// Revierte la base real a su estado previo a la restauración. Si existía
/// base, se vuelve a copiar [respaldo] sobre la ruta real, se descartan
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
}) async {
  try {
    // Libera la conexión sobre el archivo reemplazado/roto antes de tocarlo.
    await db.close();
  } catch (_) {
    // La conexión puede estar ya cerrada o en uso; se continúa igual.
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

/// Comprueba que la conexión tenga todas las tablas de Fitki.
Future<bool> _esquemaCompleto(sqflite.Database db) async {
  final filas = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  final presentes = filas
      .map((fila) => fila['name'] as String?)
      .whereType<String>()
      .toSet();
  return _tablasFitki.every(presentes.contains);
}

/// Igual que [_esquemaCompleto] y además ejecuta una consulta de lectura real
/// sobre la tabla más liviana del esquema (perfil, presente en cualquier
/// backup de Fitki) para confirmar que la base reemplazada no solo tiene el
/// esquema sino que además es legible.
Future<bool> _esquemaCompletoYLegible(sqflite.Database db) async {
  try {
    if (!await _esquemaCompleto(db)) return false;
    await db.rawQuery('SELECT COUNT(*) AS total FROM perfil');
    return true;
  } catch (_) {
    return false;
  }
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