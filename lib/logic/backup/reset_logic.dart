import '../../data/db/db_helper.dart';
import '../../data/storage/comprobante_storage.dart';

/// Borra todos los datos de Fitki: vacía todas las tablas de la base actual,
/// conservando el esquema y la conexión abierta, de modo que la app queda en
/// su estado inicial sin tocar el archivo .db ni arriesgar carreras con los
/// streams que consultan cada 500 ms.
///
/// Los comprobantes adjuntos son archivos sueltos fuera de la base; se
/// eliminan aparte para no dejar imágenes/PDF huérfanos tras borrar los
/// movimientos que los referenciaban.
///
/// Esta capa es lógica pura: no depende de Riverpod. La invalidación de los
/// providers de datos (para que la UI se refresque) la dispara la pantalla
/// mediante el callback [onBorrado].
Future<void> borrarTodosLosDatos({void Function()? onBorrado}) async {
  await DbHelper().vaciarDatos();
  await ComprobanteStorage().vaciar();
  onBorrado?.call();
}
