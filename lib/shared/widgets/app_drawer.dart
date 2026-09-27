import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/shared_providers.dart';
import '../theme/app_colors.dart';
import '../../ui/configuraciones/widgets/perfil_avatar.dart';

class AppDrawerDestination {
  const AppDrawerDestination({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

/// Menú lateral con los destinos que NO son pestañas.
///
/// Evita el carrusel de 10 items y el bottom sheet "Más" que duplicaba parte
/// de esos destinos. Cada sección se empuja por encima del shell: al entrar
/// desaparecen la barra y el menú, y el botón atrás devuelve al punto exacto
/// desde el que se salió.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const destinos = <AppDrawerDestination>[
    AppDrawerDestination(
      icon: Icons.credit_score_rounded,
      label: 'Deudas',
      route: '/deudas',
    ),
    AppDrawerDestination(
      icon: Icons.trending_up_rounded,
      label: 'Préstamos e inversiones',
      route: '/prestamos-inversiones',
    ),
    AppDrawerDestination(
      icon: Icons.insert_chart_outlined_rounded,
      label: 'Estadísticas',
      route: '/estadisticas',
    ),
    AppDrawerDestination(
      icon: Icons.ballot_rounded,
      label: 'Cotizaciones',
      route: '/cotizaciones',
    ),
    AppDrawerDestination(
      icon: Icons.flag_rounded,
      label: 'Metas',
      route: '/metas',
    ),
    AppDrawerDestination(
      icon: Icons.category_outlined,
      label: 'Categorías',
      route: '/categorias',
    ),
    AppDrawerDestination(
      icon: Icons.settings_rounded,
      label: 'Configuración',
      route: '/configuraciones',
    ),
  ];

  void _irA(BuildContext context, String route) {
    // Se resuelve el router antes de cerrar el drawer: después el contexto del
    // drawer queda desactivado y no se puede volver a consultar.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilStreamProvider).asData?.value;
    final nombre = perfil?.nombre.trim();
    final textos = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  PerfilAvatar(
                    nombre: perfil?.nombre ?? '',
                    fotoPath: perfil?.fotoPath,
                    size: 52,
                    onTap: () => _irA(context, '/configuraciones'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nombre == null || nombre.isEmpty
                              ? 'Fitki'
                              : nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tus finanzas',
                          style: textos.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: destinos.length,
                itemBuilder: (context, index) {
                  final destino = destinos[index];
                  return _DrawerItem(
                    destino: destino,
                    onTap: () => _irA(context, destino.route),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.destino, required this.onTap});

  final AppDrawerDestination destino;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(destino.icon, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    destino.label,
                    style: textos.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
