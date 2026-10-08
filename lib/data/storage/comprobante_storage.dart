import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ComprobanteStorage {
  ComprobanteStorage._();

  static final ComprobanteStorage _instance = ComprobanteStorage._();

  factory ComprobanteStorage() => _instance;

  final _uuid = const Uuid();

  Future<Directory> _getComprobantesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final comprobantesDir = Directory(join(dir.path, 'comprobantes'));
    if (!await comprobantesDir.exists()) {
      await comprobantesDir.create(recursive: true);
    }
    return comprobantesDir;
  }

  /// Guarda el archivo [archivo] en el directorio de comprobantes de la app
  /// y devuelve la ruta relativa/absoluta almacenada (ruta absoluta para
  /// facilitar apertura/lectura).
  Future<ComprobanteArchivo> guardarArchivo(File archivo) async {
    final dir = await _getComprobantesDir();
    final ext = extension(archivo.path);
    final nombreUnico = '${_uuid.v4()}$ext';
    final destino = File(join(dir.path, nombreUnico));

    await archivo.copy(destino.path);

    return ComprobanteArchivo(
      path: destino.path,
      nombre: basename(archivo.path),
      nombreAlmacenado: nombreUnico,
      sizeBytes: await destino.length(),
    );
  }

  Future<void> eliminarArchivo(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> limpiarSiOrfano(String? path) async {
    if (path == null || path.isEmpty) return;
    // Solo elimina si el archivo existe y está dentro del directorio de comprobantes
    final dir = await _getComprobantesDir();
    final file = File(path);
    if (await file.exists()) {
      final dirPath = dir.path;
      final fileDir = dirname(file.absolute.path);
      if (fileDir.startsWith(dirPath)) {
        // Es un archivo gestionado por nosotros
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}

class ComprobanteArchivo {
  final String path;
  final String nombre;
  final String nombreAlmacenado;
  final int sizeBytes;

  const ComprobanteArchivo({
    required this.path,
    required this.nombre,
    required this.nombreAlmacenado,
    required this.sizeBytes,
  });
}