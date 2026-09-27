import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/preferences/app_preferences.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/theme_providers.dart';

/// Selección de apariencia: el modo de tema (Sistema, Claro u Oscuro) y el
/// color de marca entre los siete de [AppColors.acentos].
///
/// Ambas elecciones son independientes y se guardan por separado: el modo en
/// [AppPreferences.setThemeMode] y el acento en
/// [AppPreferences.setColorPrincipal], vía [themeModeProvider] y
/// [colorPrincipalProvider].
class AparienciaScreen extends ConsumerWidget {
  const AparienciaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final acento =
        ref.watch(colorPrincipalProvider).valueOrNull ??
        AppColors.acentoPorDefecto;

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
            const _Aviso(
              icono: Icons.palette_rounded,
              texto:
                  'Elige si Fitki sigue el tema de tu dispositivo o lo '
                  'fuerza, y qué color de marca prefieres.',
            ),
            const SizedBox(height: 16),
            _seccion(context, 'Tema'),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _opcion(
                    context: context,
                    activo: modo == ThemeMode.system,
                    icono: Icons.brightness_auto_rounded,
                    titulo: 'Sistema',
                    subtitulo: 'Igual al tema de tu dispositivo',
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .cambiar(ThemeMode.system),
                  ),
                  const Divider(),
                  _opcion(
                    context: context,
                    activo: modo == ThemeMode.light,
                    icono: Icons.light_mode_rounded,
                    titulo: 'Claro',
                    subtitulo: 'Fondos claros siempre',
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .cambiar(ThemeMode.light),
                  ),
                  const Divider(),
                  _opcion(
                    context: context,
                    activo: modo == ThemeMode.dark,
                    icono: Icons.dark_mode_rounded,
                    titulo: 'Oscuro',
                    subtitulo: 'Fondos oscuros siempre',
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .cambiar(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _seccion(context, 'Color principal'),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                child: Column(
                  children: [
                    // Vista previa: muestra el acento aplicado tal como aparecerá
                    // en las app bars y en el bloque de saludo del inicio, con el
                    // texto blanco que llevan encima. Deja ver de un vistazo si
                    // el contraste funciona.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: acento.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.textOnPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fitki · ${acento.nombre}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.textOnPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'El color se aplica a la barra superior, los botones '
                        'y el saludo del inicio.',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 12,
                      children: [
                        for (final opcion in AppColors.acentos)
                          _MuestraColor(
                            acento: opcion,
                            activo: opcion.nombre == acento.nombre,
                            onTap: () => ref
                                .read(colorPrincipalProvider.notifier)
                                .cambiar(opcion),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(BuildContext context, String titulo) => Text(
    titulo,
    style: Theme.of(context).textTheme.titleSmall!.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppColors.textSecondary,
    ),
  );

  Widget _opcion({
    required BuildContext context,
    required bool activo,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icono, color: AppColors.textSecondary),
      title: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        subtitulo,
        style: Theme.of(
          context,
        ).textTheme.bodySmall!.copyWith(fontSize: 13),
      ),
      trailing: activo
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _MuestraColor extends StatelessWidget {
  const _MuestraColor({
    required this.acento,
    required this.activo,
    required this.onTap,
  });

  final AcentoMarca acento;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: activo,
      button: true,
      label: 'Color ${acento.nombre}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: acento.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: activo
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.15),
                    width: activo ? 2.5 : 1,
                  ),
                ),
                child: activo
                    ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.textOnPrimary,
                      size: 24,
                    )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                acento.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontSize: 12,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: activo
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
