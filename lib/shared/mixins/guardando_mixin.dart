import 'package:flutter/material.dart';

import '../errors/app_errores.dart';
import '../widgets/app_snackbar.dart';

/// Evita el doble envío de un formulario y bloquea la salida mientras guarda.
///
/// Integración dentro de un `State`:
/// ```dart
/// class _MiFormState extends ConsumerState<MiForm> with GuardandoMixin {
///   Future<void> _guardar() => ejecutarGuardado(_guardarReal);
///
///   Future<void> _guardarReal() async { ... }
///
///   @override
///   Widget build(BuildContext context) {
///     return protegerSalida(Scaffold(...));
///   }
/// }
/// ```
/// En el botón de guardar usar `onPressed: guardando ? null : _guardar`.
mixin GuardandoMixin<T extends StatefulWidget> on State<T> {
  bool _guardando = false;

  /// `true` mientras [ejecutarGuardado] está en curso.
  bool get guardando => _guardando;

  /// Ejecuta [accion] una sola vez: si ya hay un guardado en curso lo ignora.
  /// Cualquier error que escape se muestra con [AppErrores].
  Future<void> ejecutarGuardado(
    Future<void> Function() accion, {
    String generico = AppErrores.mensajeGenerico,
  }) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await accion();
    } catch (error) {
      if (mounted) AppErrores.mostrar(context, error, generico: generico);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Envuelve la pantalla para impedir que se cierre mientras se guarda.
  Widget protegerSalida(Widget child) {
    return PopScope(
      canPop: !_guardando,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        AppSnackbar.show(
          context,
          message: 'Espera a que termine de guardar.',
          type: AppSnackbarType.warning,
        );
      },
      child: child,
    );
  }
}
