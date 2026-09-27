import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// Avatar circular del perfil: muestra la foto si existe, las iniciales
/// calculadas del nombre en caso contrario o un ícono genérico si no hay
/// nombre.
class PerfilAvatar extends StatelessWidget {
  const PerfilAvatar({
    super.key,
    this.nombre = '',
    this.fotoPath,
    this.size = 44,
    this.fondo = AppColors.textOnPrimary,
    this.colorTexto,
    this.onTap,
  });

  final String nombre;
  final String? fotoPath;
  final double size;
  final Color fondo;
  final Color? colorTexto;
  final VoidCallback? onTap;

  String? get _iniciales {
    final nombres = nombre.trim().split(RegExp(r'\s+')).where((n) => n.isNotEmpty);
    if (nombres.isEmpty) return null;
    final primera = nombres.first.characters.first;
    final segunda = nombres.length > 1 ? nombres.elementAt(1).characters.first : '';
    return '$primera$segunda'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final foto = fotoPath;
    final tieneFoto = foto != null && File(foto).existsSync();
    final iniciales = _iniciales;
    final colorTexto = this.colorTexto ?? AppColors.primary;

    Widget contenido;
    if (tieneFoto) {
      contenido = Image.file(File(foto), fit: BoxFit.cover);
    } else if (iniciales != null) {
      contenido = Text(
        iniciales,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: colorTexto,
        ),
      );
    } else {
      contenido = Icon(
        Icons.person_rounded,
        size: size * 0.6,
        color: colorTexto,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fondo,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorTexto.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: contenido,
      ),
    );
  }
}