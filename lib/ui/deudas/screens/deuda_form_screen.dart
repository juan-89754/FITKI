import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/debt.dart';
import '../../../data/providers/shared_providers.dart';

class DeudaFormScreen extends ConsumerStatefulWidget {
  final Debt? deuda;

  const DeudaFormScreen({super.key, this.deuda});

  @override
  ConsumerState<DeudaFormScreen> createState() => _DeudaFormScreenState();
}

class _DeudaFormScreenState extends ConsumerState<DeudaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _pendienteController = TextEditingController();
  final _inicialController = TextEditingController();
  final _plazoController = TextEditingController();
  final _cuotaController = TextEditingController();
  final _tasaController = TextEditingController();
  final _observacionesController = TextEditingController();

  DateTime? _fechaProximoPago;
  bool _usarFecha = false;

  bool get _editando => widget.deuda != null;

  @override
  void initState() {
    super.initState();
    final deuda = widget.deuda;
    if (deuda != null) {
      _nombreController.text = deuda.nombreAcreedor;
      _pendienteController.text = AppFormat.montoParaEditar(deuda.montoPendiente);
      _inicialController.text = AppFormat.montoParaEditar(
        deuda.montoInicial ?? deuda.montoPendiente,
      );
      _plazoController.text = deuda.plazo ?? '';
      _cuotaController.text = deuda.valorCuota != null
          ? AppFormat.montoParaEditar(deuda.valorCuota!)
          : '';
      _tasaController.text = deuda.tasaInteres != null
          ? deuda.tasaInteres!.toStringAsFixed(2)
          : '';
      _observacionesController.text = deuda.observaciones ?? '';
      if (deuda.fechaProximoPago != null) {
        _fechaProximoPago = deuda.fechaProximoPago;
        _usarFecha = true;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _pendienteController.dispose();
    _inicialController.dispose();
    _plazoController.dispose();
    _cuotaController.dispose();
    _tasaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar deuda' : 'Nueva deuda'),
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
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del acreedor *',
                  hintText: 'Ej. Banco XYZ, Tarjeta V...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre del acreedor';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pendienteController,
                keyboardType: TextInputType.number,
                inputFormatters: const [MilesInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Monto pendiente *',
                  hintText: 'Ej. 2.500.000',
                  prefixText: r'$ ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El monto pendiente es obligatorio';
                  }
                  final monto = milesADouble(value);
                  if (monto == null || monto < 0) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inicialController,
                keyboardType: TextInputType.number,
                inputFormatters: const [MilesInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Monto inicial de la deuda *',
                  hintText: 'Ej. 3.000.000',
                  prefixText: r'$ ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El monto inicial es obligatorio';
                  }
                  final inicial = milesADouble(value);
                  if (inicial == null || inicial < 0) {
                    return 'Ingresa un monto válido';
                  }
                  final pendiente = milesADouble(_pendienteController.text);
                  if (pendiente != null && inicial < pendiente) {
                    return 'No puede ser menor que el pendiente';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plazoController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Plazo (opcional)',
                  hintText: 'Ej. 24 meses, 3 años',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cuotaController,
                keyboardType: TextInputType.number,
                inputFormatters: const [MilesInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor de la cuota mensual (opcional)',
                  hintText: 'Ej. 350.000',
                  prefixText: r'$ ',
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final monto = milesADouble(value);
                    if (monto == null || monto < 0) {
                      return 'Ingresa un valor válido';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tasaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tasa de interés anual % (opcional)',
                  hintText: 'Ej. 18.5',
                  suffixText: '%',
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final tasa = double.tryParse(value.replaceFirst(',', '.'));
                    if (tasa == null || tasa < 0) {
                      return 'Ingresa una tasa válida';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _campoFechaIngresar(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacionesController,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_editando ? 'Guardar cambios' : 'Crear deuda'),
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

  Widget _campoFechaIngresar() {
    return Column(
      children: [
        SwitchListTile(
          value: _usarFecha,
          onChanged: (value) {
            setState(() {
              _usarFecha = value;
              if (!value) _fechaProximoPago = null;
            });
          },
          title: Text(
            'Definir próxima fecha de pago',
            style: Theme.of(context).textTheme.titleSmall!,
          ),
          activeThumbColor: AppColors.primary,
          inactiveThumbColor: AppColors.surfaceSecondary,
          inactiveTrackColor: AppColors.border,
          contentPadding: EdgeInsets.zero,
        ),
        if (_usarFecha) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: _seleccionarFecha,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    _fechaProximoPago == null
                        ? 'Seleccionar fecha'
                        : DateFormat('dd MMM yyyy')
                            .format(_fechaProximoPago!),
                    style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(
                        color: _fechaProximoPago == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaProximoPago ?? hoy,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 5),
      helpText: 'Próxima fecha de pago',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.textOnPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (fecha != null) setState(() => _fechaProximoPago = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final deudaActual = widget.deuda;
    final pendiente = milesADouble(_pendienteController.text) ?? 0;
    final inicial = milesADouble(_inicialController.text);
    final cuota = milesADouble(_cuotaController.text);
    final tasa = double.tryParse(_tasaController.text.replaceFirst(',', '.'));

    final deuda = Debt(
      id: deudaActual?.id,
      nombreAcreedor: _nombreController.text.trim(),
      montoPendiente: pendiente,
      montoInicial: inicial ?? pendiente,
      plazo: _plazoController.text.trim().isEmpty
          ? null
          : _plazoController.text.trim(),
      valorCuota: cuota,
      tasaInteres: tasa,
      fechaProximoPago: _usarFecha ? _fechaProximoPago : null,
      observaciones: _observacionesController.text.trim().isEmpty
          ? null
          : _observacionesController.text.trim(),
      fechaCreacion: deudaActual?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(deudaRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(deuda);
      } else {
        await repo.insert(deuda);
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