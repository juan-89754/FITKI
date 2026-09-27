import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/quote_project.dart';
import '../cotizaciones_providers.dart';

class ProyectoFormScreen extends ConsumerStatefulWidget {
  final QuoteProject? proyecto;

  const ProyectoFormScreen({super.key, this.proyecto});

  @override
  ConsumerState<ProyectoFormScreen> createState() => _ProyectoFormScreenState();
}

class _ProyectoFormScreenState extends ConsumerState<ProyectoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _objetivoController = TextEditingController();

  bool get _editando => widget.proyecto != null;

  @override
  void initState() {
    super.initState();
    final proyecto = widget.proyecto;
    if (proyecto != null) {
      _tituloController.text = proyecto.titulo;
      _objetivoController.text = proyecto.objetivo;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _objetivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar proyecto' : 'Nuevo proyecto'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _tituloController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título del proyecto *',
                  hintText: 'Ej. Remodelación de la sala',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _objetivoController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Objetivo *',
                  hintText: '¿Qué estás intentando adquirir o lograr?',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un objetivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Ej. "Comprar un computador", "Mudanza", "Boda"...',
                style: Theme.of(context).textTheme.bodySmall!,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_editando ? 'Guardar cambios' : 'Crear proyecto'),
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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final actual = widget.proyecto;
    final proyecto = QuoteProject(
      id: actual?.id,
      titulo: _tituloController.text.trim(),
      objetivo: _objetivoController.text.trim(),
      fechaCreacion: actual?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(proyectoRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(proyecto);
      } else {
        await repo.insert(proyecto);
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
}