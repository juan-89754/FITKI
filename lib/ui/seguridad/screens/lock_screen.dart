import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../../data/preferences/app_preferences.dart';
import '../../../logic/seguridad/pin_hash.dart';
import '../../../shared/theme/app_colors.dart';
import '../widgets/pin_pad.dart';

/// Pantalla de bloqueo que aparece ANTES que cualquier otra pantalla cuando
/// el PIN está habilitado. Pide el PIN (teclado numérico) y, si la biometría
/// está activa, ofrece además el botón de huella/Face ID. Solo verifica contra
/// el hash guardado en flutter_secure_storage: un error no revela cuántos
/// dígitos acertó.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onDesbloqueado});

  /// Se invoca cuando el PIN o la biometría verifican correctamente.
  final VoidCallback onDesbloqueado;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _biometria = false;

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    try {
      final biometria = await AppPreferences.isBiometriaHabilitada();
      if (!mounted) return;
      setState(() => _biometria = biometria);
    } catch (_) {
      // Si no hay preferencias accesibles el PIN tampoco pudo estar activo.
    }
  }

  Future<String?> _validarPin(String pin) async {
    try {
      final guardado = await AppPreferences.getPinHashSeguro();
      if (guardado == null || guardado != hashPin(pin)) {
        // Error genérico: no se revela cuál dígito falló ni cuánto se corrigió.
        return 'PIN incorrecto. Intenta de nuevo.';
      }
      widget.onDesbloqueado();
      return null;
    } catch (_) {
      return 'No se pudo verificar el PIN.';
    }
  }

  Future<void> _desbloquearConBiometria() async {
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Desbloquea Fitki con tu huella o Face ID.',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) widget.onDesbloqueado();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo usar la biometría.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.textOnPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Fitki',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu información está protegida. Ingresa tu PIN para '
                  'continuar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 28),
                PinPad(
                  titulo: 'Ingresa tu PIN',
                  validar: _validarPin,
                  mostrarHuella: _biometria,
                  onHuella: _desbloquearConBiometria,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}