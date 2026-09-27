import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../data/models/perfil.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../widgets/perfil_avatar.dart';

/// Edición del perfil del usuario: foto de perfil (cámara o galería) y
/// nombre. La foto elegida se copia a un archivo permanente dentro del
/// directorio de documentos de la app, nunca se guarda la ruta temporal del
/// picker (esa carpeta se puede limpiar).
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Perfil? _perfil;
  String? _fotoPath;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final perfil = await ref.read(perfilRepositoryProvider).obtenerUno();
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _fotoPath = perfil?.fotoPath;
      if (perfil != null) _nombreController.text = perfil.nombre;
      _cargando = false;
    });
  }

  Future<void> _seleccionarFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (origen == null) return;
    await _cambiarFoto(origen);
  }

  Future<void> _cambiarFoto(ImageSource origen) async {
    try {
      final foto = await _picker.pickImage(
        source: origen,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (foto == null) return;
      final destino = await _copiarAArchivoPermanente(foto.path);
      if (!mounted) return;
      setState(() => _fotoPath = destino);
    } catch (error) {
      if (!mounted) return;
      if (_esErrorDePermiso(error)) {
        await _mostrarDialogoPermisos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar la foto: $error'),
          ),
        );
      }
    }
  }

  bool _esErrorDePermiso(Object error) {
    final texto = error.toString().toLowerCase();
    return texto.contains('permission') ||
        texto.contains('access denied') ||
        texto.contains('camera_access_denied');
  }

  Future<void> _mostrarDialogoPermisos() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permiso de cámara requerido'),
          content: const Text(
            'Fitki necesita acceso a la cámara o la galería para '
            'cambiar tu foto de perfil.\n\n'
            'Puedes habilitar el permiso desde los ajustes del sistema '
            'en la sección de permisos de la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _copiarAArchivoPermanente(String rutaOrigen) async {
    final dirDocs = await getApplicationDocumentsDirectory();
    final dirPerfil = Directory(p.join(dirDocs.path, 'perfil'));
    await dirPerfil.create(recursive: true);
    final extension = p.extension(rutaOrigen).isEmpty
        ? '.jpg'
        : p.extension(rutaOrigen);
    final destino = p.join(
      dirPerfil.path,
      'foto_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await File(rutaOrigen).copy(destino);
    return destino;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombreController.text.trim();
    final repo = ref.read(perfilRepositoryProvider);
    final previo = _perfil;

    try {
      if (previo == null) {
        await repo.insert(Perfil(nombre: nombre, fotoPath: _fotoPath));
      } else {
        await repo.update(
          previo.copyWith(nombre: nombre, fotoPath: _fotoPath),
        );
        final fotoAnterior = previo.fotoPath;
        if (fotoAnterior != null &&
            fotoAnterior != _fotoPath &&
            File(fotoAnterior).existsSync()) {
          File(fotoAnterior).delete();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar, intenta de nuevo'),
          ),
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    PerfilAvatar(
                      nombre: _nombreController.text,
                      fotoPath: _fotoPath,
                      size: 110,
                      fondo: AppColors.chipBackgroundGreen,
                      colorTexto: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: _seleccionarFoto,
                        icon: const Icon(
                          Icons.photo_camera_rounded,
                          size: 20,
                        ),
                        label: const Text('Cambiar foto'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Tu nombre',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _guardar,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _perfil == null ? 'Crear perfil' : 'Guardar cambios',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}