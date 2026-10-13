import 'package:flutter/widgets.dart';

import '../widgets/app_snackbar.dart';

/// Contrato que implementan los errores de dominio cuyo [mensaje] ya está
/// redactado para el usuario. [AppErrores] lo usa para decidir qué texto
/// mostrar sin que cada pantalla tenga que conocer los tipos concretos.
abstract interface class ErrorConMensaje {
  String get mensaje;
}

/// Punto único para traducir cualquier error atrapado en un `catch` a un
/// mensaje para el usuario y mostrarlo.
///
/// - Si el error implementa [ErrorConMensaje] (por ejemplo una operación de
///   meta o inversión rechazada) se muestra su `.mensaje`, que explica *por qué*
///   no se pudo hacer.
/// - Si no, se muestra [generico] para no filtrar detalles técnicos.
class AppErrores {
  AppErrores._();

  static const String mensajeGenerico =
      'No se pudo completar la operación. Intenta de nuevo.';

  static String mensaje(Object error, {String generico = mensajeGenerico}) {
    if (error is ErrorConMensaje) {
      final texto = error.mensaje.trim();
      if (texto.isNotEmpty) return texto;
    }
    return generico;
  }

  static void mostrar(
    BuildContext context,
    Object error, {
    String generico = mensajeGenerico,
  }) {
    AppSnackbar.show(
      context,
      message: mensaje(error, generico: generico),
      type: AppSnackbarType.error,
    );
  }
}
