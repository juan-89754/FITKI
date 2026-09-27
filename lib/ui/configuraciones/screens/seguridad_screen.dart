import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../../data/preferences/app_preferences.dart';
import '../../../logic/seguridad/pin_hash.dart';
import '../../../shared/theme/app_colors.dart';
import '../../seguridad/widgets/pin_pad.dart';

/// Configuración de seguridad: bloqueo con PIN (hashsha256 en
/// flutter_secure_storage, nunca en texto plano) y desbloqueo opcional con
/// huella/Face ID cuando el dispositivo lo soporta.
///
/// LIMITACIÓN CONOCIDA (por decisión de producto en esta versión): no hay
/// recuperación de PIN olvidado. Si el usuario olvida su PIN, la única opción
/// por ahora es desinstalar/reinstalar la app, lo que elimina los datos
/// locales. No se implementa un flujo de recuperación adicional.
class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  bool _pinHabilitado = false;
  bool _biometriaHabilitada = false;
  bool _biometriaDisponible = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    var pin = false;
    var biometria = false;
    var disponible = false;
    try {
      pin = await AppPreferences.isPinHabilitado();
      biometria = await AppPreferences.isBiometriaHabilitada();
      disponible = await _biometriaDisponibleEnDispositivo();
    } catch (_) {
      // Sin preferencias accesibles se deja todo desactivado.
    }
    if (!mounted) return;
    setState(() {
      _pinHabilitado = pin;
      _biometriaHabilitada = biometria;
      _biometriaDisponible = disponible;
      _cargando = false;
    });
  }

  Future<bool> _biometriaDisponibleEnDispositivo() async {
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Widget _dialogoPin(PinPad pad) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: SizedBox(width: 320, child: pad),
      ),
    );
  }

  Future<void> _crearPin() async {
    // Paso 1: crear el PIN.
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => _dialogoPin(
        PinPad(
          titulo: 'Nuevo PIN',
          subtitulo: 'Elige un PIN de 4 a 6 dígitos.',
          onAceptar: (pin) => Navigator.of(context).pop(pin),
        ),
      ),
    );
    if (pin == null || !mounted) return;

    // Paso 2: confirmarlo.
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => _dialogoPin(
        PinPad(
          titulo: 'Repite tu PIN',
          validar: (pinRepetido) async =>
              pinRepetido == pin ? null : 'Los PIN no coinciden.',
          onAceptar: (_) => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await AppPreferences.setPinHashSeguro(hashPin(pin));
      await AppPreferences.setPinHabilitado(true);
    } catch (_) {
      try {
        await AppPreferences.setPinHashSeguro(null);
        await AppPreferences.setPinHabilitado(false);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo activar el PIN, intenta de nuevo'),
        ),
      );
      return;
    }

    // Tras activar el PIN, la biometría queda disponible para activarla aparte.
    final biometria = await _biometriaDisponibleEnDispositivo();
    if (!mounted) return;
    setState(() {
      _pinHabilitado = true;
      _biometriaHabilitada = false;
      _biometriaDisponible = biometria;
    });
  }

  Future<void> _desactivarPin() async {
    // Pedir el PIN actual antes de desactivar el bloqueo y borrar el hash.
    final autorizado = await showDialog<bool>(
      context: context,
      builder: (context) => _dialogoPin(
        PinPad(
          titulo: 'Ingresa tu PIN actual',
          validar: (pin) async {
            final guardado = await AppPreferences.getPinHashSeguro();
            return guardado != null && guardado == hashPin(pin)
                ? null
                : 'PIN incorrecto.';
          },
          onAceptar: (_) => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (autorizado != true || !mounted) return;

    try {
      // El flag se apaga primero: si un guardado posterior falla, nunca queda
      // el bloqueo activo sin hash que validar (riesgo de quedar fuera).
      await AppPreferences.setPinHabilitado(false);
      await AppPreferences.setPinHashSeguro(null);
      await AppPreferences.setBiometriaHabilitada(false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo desactivar el PIN, intenta de nuevo'),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _pinHabilitado = false;
      _biometriaHabilitada = false;
    });
  }

  Future<void> _cambiarBiometria(bool valor) async {
    if (valor) {
      // Activar exige autenticarse primero (confirma que el sensor funciona).
      try {
        final auth = LocalAuthentication();
        final ok = await auth.authenticate(
          localizedReason: 'Habilita el desbloqueo sin PIN con tu huella o '
              'Face ID.',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!ok) return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo usar la biometría.')),
        );
        return;
      }
    }
    await AppPreferences.setBiometriaHabilitada(valor);
    if (!mounted) return;
    setState(() => _biometriaHabilitada = valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seguridad'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bloquea Fitki al abrir la app para que nadie más '
                            'pueda ver tus finanzas.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      title: const Text('Bloquear con PIN'),
                      subtitle: const Text(
                        'Pide un PIN de 4 a 6 dígitos al abrir la app.',
                      ),
                      value: _pinHabilitado,
                      activeTrackColor: AppColors.primary,
                      onChanged: (valor) =>
                          valor ? _crearPin() : _desactivarPin(),
                    ),
                  ),
                  if (_pinHabilitado && _biometriaDisponible) ...[
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: SwitchListTile(
                        title: const Text('Usar huella / Face ID'),
                        subtitle: const Text(
                          'Desbloquear sin PIN cuando el sensor esté '
                          'disponible.',
                        ),
                        value: _biometriaHabilitada,
                        activeTrackColor: AppColors.primary,
                        onChanged: _cambiarBiometria,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.coral.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'No hay recuperación de PIN olvidado en esta versión. '
                      'Si lo olvidas, deberás desinstalar y reinstalar la app '
                      '(se pierden los datos locales).',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.coral,
                          ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}