import 'package:flutter/material.dart';

/// Logo de la app tal como está en `assets/icon/icon.png`.
///
/// La misma imagen de la que `tool/generate_launcher_icons.ps1` genera los
/// iconos de cada plataforma, para que el launcher y la app no se vean
/// distintos. El recurso debe estar declarado en `pubspec.yaml`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64, this.radio = 0.22});

  final double size;

  /// Proporción del lado que ocupa el redondeo de las esquinas, igual que en
  /// el script que genera los iconos.
  final double radio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * radio),
      child: Image.asset(
        'assets/icon/icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // El archivo está siempre en el paquete; si faltara, el hueco se ve
        // durante la decodificación solo.
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
