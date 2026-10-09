import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../data/models/financial_goal.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../data/providers/shared_providers.dart';

class MetaFormScreen extends ConsumerStatefulWidget {
  final FinancialGoal? meta;

  const MetaFormScreen({super.key, this.meta});

  @override
  ConsumerState<MetaFormScreen> createState() => _MetaFormScreenState();
}

class _MetaFormScreenState extends ConsumerState<MetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _objetivoController = TextEditingController();
  final _comentariosController = TextEditingController();

  String _finalidad = 'viaje';
  DateTime? _fechaEstimada;
  bool _usarFecha = false;

  bool get _editando => widget.meta != null;

  @override
  void initState() {
    super.initState();
    final meta = widget.meta;
    if (meta != null) {
      _nombreController.text = meta.nombre;
      _objetivoController.text = meta.montoObjetivo != null
          ? AppFormat.montoParaEditar(meta.montoObjetivo!)
          : '';
      _comentariosController.text = meta.comentarios ?? '';
      _finalidad = finalidades.contains(meta.finalidad)
          ? meta.finalidad
          : 'otro';
      if (meta.fechaEstimada != null) {
        _fechaEstimada = meta.fechaEstimada;
        _usarFecha = true;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _objetivoController.dispose();
    _comentariosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar meta' : 'Nueva meta'),
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
              _campoNombre(),
              const SizedBox(height: 16),
              _campoObjetivo(),
              const SizedBox(height: 16),
              _campoFinalidad(),
              const SizedBox(height: 16),
              _campoFecha(),
              const SizedBox(height: 16),
              _campoComentarios(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_editando ? 'Guardar cambios' : 'Crear meta'),
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

  Widget _campoNombre() {
    return TextFormField(
      controller: _nombreController,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Nombre de la meta *',
        hintText: 'Ej. Viaje a Europa',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa un nombre';
        }
        return null;
      },
    );
  }

  Widget _campoObjetivo() {
    return TextFormField(
      controller: _objetivoController,
      keyboardType: TextInputType.number,
      inputFormatters: const [MilesInputFormatter()],
      decoration: const InputDecoration(
        labelText: 'Monto objetivo (opcional)',
        hintText: 'Ej. 5.000.000',
        prefixText: r'$ ',
      ),
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          final monto = milesADouble(value);
          if (monto == null || monto <= 0) {
            return 'Ingresa un monto válido';
          }
        }
        return null;
      },
    );
  }

  Widget _campoFinalidad() {
    return DropdownButtonFormField<String>(
      initialValue: _finalidad,
      decoration: const InputDecoration(labelText: 'Finalidad'),
      items: finalidades
          .map((finalidad) => DropdownMenuItem(
                value: finalidad,
                child: Text(labelFinalidad(finalidad)),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _finalidad = value);
      },
    );
  }

  Widget _campoFecha() {
    return Column(
      children: [
        SwitchListTile(
          value: _usarFecha,
          onChanged: (value) {
            setState(() {
              _usarFecha = value;
              if (!value) _fechaEstimada = null;
            });
          },
          title: Text(
            'Definir fecha estimada',
            style: Theme.of(context).textTheme.titleSmall!,
          ),
          activeThumbColor: AppColors.primary,
          inactiveThumbColor: AppColors.surfaceSecondary,
          inactiveTrackColor: AppColors.border,
          contentPadding: EdgeInsets.zero,
        ),
        if (_usarFecha) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: _seleccionarFecha,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _fechaEstimada == null
                        ? 'Seleccionar fecha'
                        : DateFormat('dd MMM yyyy').format(_fechaEstimada!),
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: _fechaEstimada == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_fechaEstimada != null) ...[
            const SizedBox(height: 4),
            if (_fechaEstimada!.isBefore(DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'La fecha está en el pasado',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: AppColors.coral,
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _campoComentarios() {
    return TextFormField(
      controller: _comentariosController,
      maxLines: 3,
      maxLength: 300,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Comentarios / condiciones (opcional)',
        alignLabelWithHint: true,
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaEstimada ?? hoy,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 10),
      helpText: 'Fecha estimada de cumplimiento',
    );
    if (fecha != null) setState(() => _fechaEstimada = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final metaActual = widget.meta;
    final montoObjetivo = milesADouble(_objetivoController.text);

    final meta = FinancialGoal(
      id: metaActual?.id,
      nombre: _nombreController.text.trim(),
      montoObjetivo: montoObjetivo,
      finalidad: _finalidad,
      fechaEstimada: _usarFecha ? _fechaEstimada : null,
      comentarios: _comentariosController.text.trim().isEmpty
          ? null
          : _comentariosController.text.trim(),
      montoAhorrado: metaActual?.montoAhorrado ?? 0,
      fechaCreacion: metaActual?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(metaRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(meta);
      } else {
        await repo.insert(meta);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context, true);
  }
}