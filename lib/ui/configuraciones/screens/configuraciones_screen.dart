import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/preferences/app_preferences.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../home/tab_navigation.dart';
import '../widgets/perfil_avatar.dart';

/// Pantalla central de Configuraciones: une el perfil, las preferencias
/// (apariencia, notificaciones y umbral de alerta de deuda) y el acceso a
/// categorías, backup/restauración y "Acerca de".
class ConfiguracionesScreen extends ConsumerStatefulWidget {
  const ConfiguracionesScreen({super.key});

  @override
  ConsumerState<ConfiguracionesScreen> createState() =>
      _ConfiguracionesScreenState();
}

class _ConfiguracionesScreenState extends ConsumerState<ConfiguracionesScreen> {
  /// Versión mostrada en "Acerca de". Se mantiene alineada con el campo
  /// `version` de pubspec.yaml; no se agrega package_info_plus todavía.
  static const String _versionApp = '0.1.0';

  bool _cargandoUmbral = true;
  double _umbralCargaDeuda = AppPreferences.umbralCargaDeudaDefault;
  /// Último valor del umbral realmente persistido en preferencias; sirve de
  /// referencia para descartar guardados no-op y para revertir el slider si
  /// un guardado falla.
  double _umbralGuardado = AppPreferences.umbralCargaDeudaDefault;
  // ignore: unused_field
  bool _cargandoNotificaciones = true;
  bool _notificacionesHabilitadas = false;

  @override
  void initState() {
    super.initState();
    _cargarUmbral();
    _cargarNotificaciones();
  }

  Future<void> _cargarUmbral() async {
    final umbral = await AppPreferences.getUmbralCargaDeuda();
    if (!mounted) return;
    setState(() {
      _umbralCargaDeuda = umbral;
      _umbralGuardado = umbral;
      _cargandoUmbral = false;
    });
  }

  Future<void> _guardarUmbral(double valor) async {
    final ultimoPersistido = _umbralGuardado;
    if (valor == ultimoPersistido) return;
    try {
      await AppPreferences.setUmbralCargaDeuda(valor);
      if (!mounted) return;
      setState(() => _umbralGuardado = valor);
      ref.invalidate(umbralCargaDeudaProvider);
    } catch (_) {
      if (!mounted) return;
      // Si el guardado falló, el slider vuelve al último valor que realmente
      // quedó persistido: la UI no debe mostrar un estado que no corresponde.
      setState(() => _umbralCargaDeuda = ultimoPersistido);
      AppSnackbar.show(
        context,
        message: 'No se pudo guardar el umbral, intenta de nuevo',
        type: AppSnackbarType.error,
      );
    }
  }

  Future<void> _cargarNotificaciones() async {
    final habilitadas = await AppPreferences.areNotificacionesHabilitadas();
    if (!mounted) return;
    setState(() {
      _notificacionesHabilitadas = habilitadas;
      _cargandoNotificaciones = false;
    });
  }

  // ignore: unused_element
  Future<void> _cambiarNotificaciones(bool valor) async {
    final ultimoPersistido = _notificacionesHabilitadas;
    try {
      await AppPreferences.setNotificacionesHabilitadas(valor);
      if (!mounted) return;
      setState(() => _notificacionesHabilitadas = valor);
    } catch (_) {
      if (!mounted) return;
      // Si el guardado falló, el switch vuelve al valor realmente persistido.
      setState(() => _notificacionesHabilitadas = ultimoPersistido);
      AppSnackbar.show(
        context,
        message: 'No se pudo guardar la preferencia, intenta de nuevo',
        type: AppSnackbarType.error,
      );
    }
  }

  void _mostrarAcercaDe() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 88),
              const SizedBox(height: 12),
              Text(
                'Fitki',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Finanzas personales sin complicaciones.\n\n'
                'Versión $_versionApp',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilStreamProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuraciones'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TarjetaPerfil(
            nombre: perfil?.nombre ?? '',
            fotoPath: perfil?.fotoPath,
            onTap: () => context.push('/configuraciones/perfil'),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Preferencias'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
            child: Column(
              children: [
                _FilaOpcion(
                  icono: Icons.palette_rounded,
                  colorIcono: AppColors.chipBackgroundOrange,
                  colorFrente: AppColors.orange,
                  titulo: 'Apariencia',
                  subtitulo: 'Tema claro, oscuro y colores de la app',
                  onTap: () => context.push('/configuraciones/apariencia'),
                ),
                // TODO: reactivar cuando se implemente el motor de

                // notificaciones (sección 18.9 del módulo de Configuraciones).
                // Se oculta temporalmente el switch: la preferencia se sigue
                // persistiendo en AppPreferences.notificacionesHabilitadas.
                /*
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 64,
                  color: AppColors.borderSubtle,
                ),
                SwitchListTile(
                  value: _cargandoNotificaciones
                      ? false
                      : _notificacionesHabilitadas,
                  activeTrackColor: AppColors.primary,
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.chipBackgroundCoral,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.coral,
                      size: 20,
                    ),
                  ),
                  title: const Text('Notificaciones'),
                  subtitle: const Text(
                    'Avisos y recordatorios de la app.',
                  ),
                  onChanged: _cargandoNotificaciones ? null : _cambiarNotificaciones,
                ),
                */
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Finanzas'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.percent_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Umbral de alerta de deuda',
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(_umbralCargaDeuda * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _umbralCargaDeuda,
                  min: 0.10,
                  max: 0.70,
                  divisions: 12,
                  label: '${(_umbralCargaDeuda * 100).toStringAsFixed(0)}%',
                  onChanged: _cargandoUmbral
                      ? null
                      : (valor) => setState(() => _umbralCargaDeuda = valor),
                  onChangeEnd: _guardarUmbral,
                ),
                Text(
                  'Te avisaremos si tus cuotas mensuales de deuda superan '
                  'este porcentaje de tus ingresos.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Organización'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
            child: _FilaOpcion(
              icono: Icons.category_outlined,
              colorIcono: AppColors.chipBackgroundPrimary,
              colorFrente: AppColors.primary,
              titulo: 'Categorías personalizadas',
              subtitulo: 'Gestiona tus categorías de gasto e ingreso',
              onTap: () => irAModulo(context, TabIndex.categorias),
            ),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Datos'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
            child: _FilaOpcion(
              icono: Icons.backup_rounded,
              colorIcono: AppColors.chipBackgroundOlive,
              colorFrente: AppColors.oliveGreen,
              titulo: 'Backup y restauración',
              subtitulo: 'Copia, restaura o borra todos tus datos',
              onTap: () => context.push('/configuraciones/backup'),
            ),
          ),
          const SizedBox(height: 28),
          const _TituloSeccion('Información'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
            child: _FilaOpcion(
              icono: Icons.info_outline_rounded,
              colorIcono: AppColors.chipBackgroundOrange,
              colorFrente: AppColors.orange,
              titulo: 'Acerca de',
              onTap: _mostrarAcercaDe,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección (título en mayúsculas, estilo consistente con el de
/// las tarjetas del home).
class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Fila de opción con ícono circular de color, título (y subtítulo opcional)
/// y chevron, consistente con las opciones del menú "Más".
class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion({
    required this.icono,
    required this.colorIcono,
    required this.colorFrente,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final Color colorIcono;
  final Color colorFrente;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: colorIcono, shape: BoxShape.circle),
        child: Icon(icono, color: colorFrente, size: 20),
      ),
      title: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 15),
      ),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo!,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Tarjeta de perfil en la parte superior: avatar + nombre. Tocar abre la
/// edición de perfil.
class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({
    required this.nombre,
    required this.fotoPath,
    required this.onTap,
  });

  final String nombre;
  final String? fotoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tieneNombre = nombre.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PerfilAvatar(
                nombre: nombre,
                fotoPath: fotoPath,
                size: 56,
                fondo: AppColors.chipBackgroundPrimary,
                colorTexto: AppColors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tieneNombre ? nombre : 'Tu perfil',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tieneNombre ? 'Toca para editar tu perfil' : 'Crea tu perfil',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}