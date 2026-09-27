import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// Teclado numérico simple para ingresar un PIN de 4 a 6 dígitos, con
/// indicador de avance y error propio. Lo usan tanto la pantalla de bloqueo
/// como la configuración de seguridad (crear/confirmar/verificar PIN).
///
/// [validar] permite validar el PIN al pulsar la tecla de aceptar: si devuelve
/// un mensaje, se muestra como error y el teclado se reinicia sin revelar qué
/// dígito falló. Si devuelve null (o no se provee), se llama a [onAceptar].
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.longitudMin = 4,
    this.longitudMax = 6,
    this.validar,
    this.onAceptar,
    this.mostrarHuella = false,
    this.onHuella,
  })  : assert(longitudMin >= 1 && longitudMin <= longitudMax),
        assert(longitudMax <= 10);

  final String titulo;
  final String? subtitulo;
  final int longitudMin;
  final int longitudMax;

  /// Valida el PIN ingresado. Devuelve un mensaje de error o null si es válido.
  final Future<String?> Function(String pin)? validar;

  /// Se invoca cuando el PIN es válido (validar devolvió null o no se proveyó),
  /// con el PIN ingresado como argumento.
  final ValueChanged<String>? onAceptar;
  final bool mostrarHuella;
  final VoidCallback? onHuella;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  final List<int> _digitos = [];
  String? _error;

  bool get _puedeAceptar => _digitos.length >= widget.longitudMin;

  void _presionar(int digito) {
    setState(() {
      // Después de un error, el primer toque reinicia la entrada desde cero.
      _error = null;
      if (_digitos.length < widget.longitudMax) {
        _digitos.add(digito);
      }
    });
  }

  void _borrar() {
    setState(() {
      _error = null;
      if (_digitos.isNotEmpty) _digitos.removeLast();
    });
  }

  void _aceptar() async {
    if (!_puedeAceptar) return;
    final pin = _digitos.join();
    final validar = widget.validar;
    if (validar != null) {
      final mensaje = await validar(pin);
      if (!mounted) return;
      if (mensaje != null) {
        setState(() {
          _digitos.clear();
          _error = mensaje;
        });
        return;
      }
    }
    widget.onAceptar?.call(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.titulo,
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
        if (widget.subtitulo != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitulo!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
        const SizedBox(height: 24),
        _indicador(context),
        SizedBox(
          height: 24,
          child: _error == null
              ? null
              : Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _teclado(context),
      ],
    );
  }

  Widget _indicador(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.longitudMax, (i) {
        final lleno = i < _digitos.length;
        final error = _error != null;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? AppColors.coral.withValues(alpha: 0.25)
                : lleno
                    ? AppColors.primary
                    : AppColors.borderSubtle,
            border: Border.all(
              color: error
                  ? AppColors.coral
                  : lleno
                      ? AppColors.primary
                      : AppColors.border,
              width: 1,
            ),
          ),
        );
      }),
    );
  }

  Widget _teclado(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _fila([1, 2, 3]),
        const SizedBox(height: 14),
        _fila([4, 5, 6]),
        const SizedBox(height: 14),
        _fila([7, 8, 9]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tecla(icono: Icons.backspace_outlined, onTap: _borrar),
            const SizedBox(width: 18),
            _tecla(numero: 0),
            const SizedBox(width: 18),
            _tecla(
              icono: Icons.check_rounded,
              habilitada: _puedeAceptar,
              colorIcono: AppColors.primary,
              onTap: _aceptar,
            ),
          ],
        ),
        if (widget.mostrarHuella) ...[
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: widget.onHuella,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Usar huella o Face ID'),
          ),
        ],
      ],
    );
  }

  Widget _fila(List<int> numeros) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tecla(numero: numeros[0]),
        const SizedBox(width: 18),
        _tecla(numero: numeros[1]),
        const SizedBox(width: 18),
        _tecla(numero: numeros[2]),
      ],
    );
  }

  Widget _tecla({
    int? numero,
    IconData? icono,
    bool habilitada = true,
    Color? colorIcono,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 62,
      height: 56,
      child: TextButton(
        onPressed: habilitada && numero != null
            ? () => _presionar(numero)
            : habilitada
                ? onTap
                : null,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(side: BorderSide.none),
          backgroundColor: habilitada
              ? AppColors.surfaceSecondary
              : AppColors.borderSubtle,
          foregroundColor: habilitada ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        child: numero != null
            ? Text(
                '$numero',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  fontSize: 22,
                  color: habilitada
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              )
            : Icon(icono, size: 24, color: colorIcono ?? AppColors.textSecondary),
      ),
    );
  }
}