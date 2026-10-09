import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/preferences/app_preferences.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/backup/backup_logic.dart';
import '../../../logic/backup/reset_logic.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../cotizaciones/cotizaciones_providers.dart';
import '../../deudas/deudas_providers.dart';
import '../../metas/metas_providers.dart';
import '../../movimientos/movimientos_providers.dart';
import '../../presupuesto/presupuesto_providers.dart';
import '../../prestamos_inversiones/prestamos_inversiones_providers.dart';

/// Backup y restauración manual de todos los datos de Fitki. El backup es el
/// archivo .db completo compartido vía el sheet nativo de Android/iOS (sin
/// pedir permisos de almacenamiento). El aviso de restauración advierte
/// explícitamente que se reemplazan todos los datos actuales.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  DateTime? _fechaUltimoBackup;
  bool _procesando = false;
  bool _borrando = false;

  @override
  void initState() {
    super.initState();
    _cargarFechaUltimoBackup();
  }

  Future<void> _cargarFechaUltimoBackup() async {
    final fecha = await AppPreferences.getFechaUltimoBackup();
    if (!mounted) return;
    setState(() => _fechaUltimoBackup = fecha);
  }

  void _invalidarDatos() {
    ref.invalidate(activosStreamProvider);
    ref.invalidate(movimientosStreamProvider);
    ref.invalidate(metasStreamProvider);
    ref.invalidate(deudasStreamProvider);
    ref.invalidate(proyectosStreamProvider);
    ref.invalidate(cotizacionesStreamProvider);
    ref.invalidate(itemsStreamProvider);
    ref.invalidate(prestamosStreamProvider);
    ref.invalidate(inversionesStreamProvider);
    ref.invalidate(perfilStreamProvider);
    // Los providers de Presupuesto y Gastos Fijos tienen su propia tabla y
    // además generan los pagos del mes a partir de sus plantillas; tras
    // restaurar o borrar hay que refrescarlos explícitamente.
    ref.invalidate(presupuestosActivosStreamProvider);
    ref.invalidate(gastosFijosStreamProvider);
    ref.invalidate(pagosGastosFijosStreamProvider);
    ref.invalidate(pagosDelMesProvider);
  }

  Future<void> _generarBackup() async {
    setState(() => _procesando = true);
    try {
      final rutaBackup = await generarBackup();
      await AppPreferences.setFechaUltimoBackup(DateTime.now());
      if (!mounted) return;

      final xfile = XFile(
        rutaBackup,
        mimeType: 'application/x-sqlite3',
      );
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xfile],
        subject: 'Backup de Fitki',
        text: 'Copia de seguridad de mis datos de Fitki.',
      );

      final fecha = await AppPreferences.getFechaUltimoBackup();
      if (!mounted) return;
      setState(() {
        _fechaUltimoBackup = fecha;
        _procesando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      AppSnackbar.show(
        context,
        message: 'No se pudo generar el backup, intenta de nuevo',
        type: AppSnackbarType.error,
      );
    }
  }

  Future<void> _seleccionarYRestaurar() async {
    final archivo = await FilePicker.pickFile(
      dialogTitle: 'Elegir backup de Fitki (.db)',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    final ruta = archivo?.path;
    if (ruta == null) return;

    final confirmado = await _confirmarRestauracion();
    if (confirmado != true) return;

    setState(() => _procesando = true);
    try {
      await restaurarBackup(ruta, onRestaurado: _invalidarDatos);
      if (!mounted) return;
      setState(() => _procesando = false);
      await _mostrarExitoRestauracion();
    } on FileSystemException catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      AppSnackbar.show(
        context,
        message: 'El archivo elegido no existe',
        type: AppSnackbarType.error,
      );
    } on FormatException catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      AppSnackbar.show(
        context,
        message: 'Este archivo no es un backup válido de Fitki',
        type: AppSnackbarType.error,
      );
    } on RestauracionRevertidaException catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      AppSnackbar.show(
        context,
        message: RestauracionRevertidaException.mensajeUsuario,
        type: AppSnackbarType.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      AppSnackbar.show(
        context,
        message: 'No se pudo restaurar, intenta de nuevo',
        type: AppSnackbarType.error,
      );
    }
  }

  Future<bool?> _confirmarRestauracion() {
    return AppDialog.confirm(
      context: context,
      title: 'Restaurar backup',
      message:
          'Vas a reemplazar TODOS los datos actuales de Fitki por los '
          'contenidos en el backup elegido. Esta acción no se puede '
          'deshacer.',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
  }

  Future<void> _mostrarExitoRestauracion() {
    return AppDialog.info(
      context: context,
      title: 'Backup restaurado',
      message:
          'Tus datos se restauraron correctamente. Se recomienda cerrar y '
          'volver a abrir la app para asegurar que todo se recargue.',
    );
  }

  Future<void> _borrarTodosLosDatos() async {
    final primeraConfirmacion = await _confirmarBorrado();
    if (primeraConfirmacion != true) return;

    final segundaConfirmacion = await _confirmarBorradoConTexto();
    if (segundaConfirmacion != true) return;

    setState(() => _borrando = true);
    try {
      await borrarTodosLosDatos(onBorrado: _invalidarDatos);
      if (!mounted) return;
      setState(() => _borrando = false);
      await _mostrarExitoBorrado();
    } catch (_) {
      if (!mounted) return;
      setState(() => _borrando = false);
      AppSnackbar.show(
        context,
        message: 'No se pudieron borrar los datos, intenta de nuevo',
        type: AppSnackbarType.error,
      );
    }
  }

  Future<bool?> _confirmarBorrado() {
    return AppDialog.confirm(
      context: context,
      title: '¿Borrar todos los datos?',
      message:
          'Se eliminarán permanentemente tus movimientos, cuentas, metas, '
          'deudas, préstamos, cotizaciones, presupuestos y perfil. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Continuar',
      destructive: true,
    );
  }

  Future<bool?> _confirmarBorradoConTexto() async {
    final controller = TextEditingController();
    // El botón se activa en cuanto el campo tiene texto; se propaga con un
    // ValueNotifier para que el AlertDialog se reconstruya de forma reactiva
    // (tanto vía el listener del controller como por onChanged del TextField).
    final notificador = ValueNotifier<bool>(false);
    controller.addListener(() {
      final hayTexto = controller.text.trim().isNotEmpty;
      if (hayTexto != notificador.value) notificador.value = hayTexto;
    });

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: notificador,
          builder: (context, hayTexto, _) {
            return AlertDialog(
              title: const Text('Confirmación final'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escribe cualquier texto para confirmar que quieres '
                    'eliminar todos los datos de Fitki.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      hintText: 'Escribe aquí para confirmar',
                    ),
                    onSubmitted: (_) {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  onPressed: hayTexto
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Borrar todo'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    notificador.dispose();
    return resultado;
  }

  Future<void> _mostrarExitoBorrado() {
    return AppDialog.info(
      context: context,
      title: 'Datos borrados',
      message:
          'Se borraron todos tus registros financieros y tu perfil: '
          'activos, movimientos, deudas, metas, préstamos, cotizaciones y '
          'presupuestos.\n\n'
          'Tus preferencias de apariencia, seguridad (PIN), notificaciones '
          'y umbral de alerta siguen intactas.',
    );
  }

  String get _textoUltimoBackup {
    final fecha = _fechaUltimoBackup;
    if (fecha == null) return 'Nunca se ha generado un backup.';
    return 'Último backup: ${DateFormat('dd MMM yyyy, HH:mm', 'es').format(fecha)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Backup y restauración'),
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
                    Icons.history_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _textoUltimoBackup,
                      style: Theme.of(context).textTheme.titleSmall!,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _procesando || _borrando ? null : _generarBackup,
              icon: const Icon(Icons.backup_rounded),
              label: const Text('Generar backup'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Genera una copia del archivo .db de Fitki y compártela donde '
              'quieras (Drive, WhatsApp, gestor de archivos…).',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _procesando || _borrando ? null : _seleccionarYRestaurar,
              icon: const Icon(Icons.settings_backup_restore_rounded),
              label: const Text('Restaurar backup'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: const BorderSide(color: AppColors.coral),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reemplaza todos los datos actuales por los del archivo .db '
              'elegido. No se puede deshacer y se pregunta antes de continuar.',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.coral.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.coral,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zona de peligro',
                        style:
                            Theme.of(context).textTheme.titleSmall!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.coral,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estas acciones son irreversibles.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.coral,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _procesando || _borrando
                        ? null
                        : _borrarTodosLosDatos,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Borrar todos los datos'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (_borrando) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
            if (_procesando) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}