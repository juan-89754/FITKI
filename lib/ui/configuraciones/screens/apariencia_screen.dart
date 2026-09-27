import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/theme_providers.dart';

/// Selección de apariencia: Sistema, Claro o Rojo (tema claro con acento
/// rojo en lugar del verde clásico). El valor elegido se persiste en
/// [AppPreferences] vía [themeModeProvider] y [temaRojoProvider].
class AparienciaScreen extends ConsumerWidget {
  const AparienciaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final rojo = ref.watch(temaRojoProvider).valueOrNull ?? false;

    // El "Rojo" reemplaza al antiguo "Oscuro": los usuarios que traigan ese
    // valor persistido ven marcado "Rojo" hasta que elijan otra opción.
    final esRojoActivo = rojo || (!rojo && modo == ThemeMode.dark);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Apariencia'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: SingleChildScrollView(
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
                    Icons.palette_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Elige cómo se ve Fitki: claro, siguiendo la '
                      'configuración de tu dispositivo, o con el acento rojo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _opcion(
                    textTheme: Theme.of(context).textTheme,
                    activo: !rojo && modo == ThemeMode.system,
                    icono: Icons.brightness_auto_rounded,
                    titulo: 'Sistema',
                    subtitulo: 'Igual al tema de tu dispositivo',
                    onTap: () {
                      ref.read(temaRojoProvider.notifier).cambiar(false);
                      ref.read(themeModeProvider.notifier).cambiar(
                        ThemeMode.system,
                      );
                    },
                  ),
                  const Divider(),
                  _opcion(
                    textTheme: Theme.of(context).textTheme,
                    activo: !rojo && modo == ThemeMode.light,
                    icono: Icons.light_mode_rounded,
                    titulo: 'Claro',
                    subtitulo: 'Fondos claros con acento verde',
                    onTap: () {
                      ref.read(temaRojoProvider.notifier).cambiar(false);
                      ref.read(themeModeProvider.notifier).cambiar(
                        ThemeMode.light,
                      );
                    },
                  ),
                  const Divider(),
                  _opcion(
                    textTheme: Theme.of(context).textTheme,
                    activo: esRojoActivo,
                    icono: Icons.colorize_rounded,
                    titulo: 'Rojo',
                    subtitulo: 'Fondos claros con acento rojo',
                    onTap: () {
                      ref.read(temaRojoProvider.notifier).cambiar(true);
                      ref.read(themeModeProvider.notifier).cambiar(
                        ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion({
    required TextTheme textTheme,
    required bool activo,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icono, color: AppColors.textSecondary),
      title: Text(
        titulo,
        style: textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitulo,
        style: textTheme.bodySmall!.copyWith(fontSize: 13),
      ),
      trailing: activo
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}