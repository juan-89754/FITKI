import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/quote.dart';
import '../cotizaciones_providers.dart';

class CotizacionFormScreen extends ConsumerStatefulWidget {
  final int proyectoId;
  final Quote? cotizacion;

  const CotizacionFormScreen({
    super.key,
    required this.proyectoId,
    this.cotizacion,
  });

  @override
  ConsumerState<CotizacionFormScreen> createState() =>
      _CotizacionFormScreenState();
}

class _CotizacionFormScreenState extends ConsumerState<CotizacionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _notasController = TextEditingController();

  bool get _editando => widget.cotizacion != null;

  @override
  void initState() {
    super.initState();
    final cotizacion = widget.cotizacion;
    if (cotizacion != null) {
      _tituloController.text = cotizacion.titulo;
      _notasController.text = cotizacion.notas ?? '';
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar cotización' : 'Nueva cotización'),
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
                  labelText: 'Título de la cotización *',
                  hintText: 'Ej. Tienda A, Mercado Libre, Proveedor local',
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
                controller: _notasController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Ej. Incluye envío, tiempo de entrega...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _editando ? 'Guardar cambios' : 'Crear cotización',
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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final actual = widget.cotizacion;
    final notas = _notasController.text.trim().isEmpty
        ? null
        : _notasController.text.trim();
    final cotizacion = Quote(
      id: actual?.id,
      proyectoId: actual?.proyectoId ?? widget.proyectoId,
      titulo: _tituloController.text.trim(),
      notas: notas,
      fechaCreacion: actual?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(cotizacionRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(cotizacion);
      } else {
        await repo.insert(cotizacion);
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