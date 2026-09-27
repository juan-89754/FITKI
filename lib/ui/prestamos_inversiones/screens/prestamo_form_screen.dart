import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/loan.dart';
import '../../../data/providers/shared_providers.dart';

class PrestamoFormScreen extends ConsumerStatefulWidget {
  final Loan? prestamo;

  const PrestamoFormScreen({super.key, this.prestamo});

  @override
  ConsumerState<PrestamoFormScreen> createState() => _PrestamoFormScreenState();
}

class _PrestamoFormScreenState extends ConsumerState<PrestamoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beneficiarioController = TextEditingController();
  final _montoController = TextEditingController();
  final _condicionesController = TextEditingController();
  final _observacionesController = TextEditingController();

  late DateTime _fechaPrestamo;
  late DateTime _fechaPagoEsperada;

  bool get _editando => widget.prestamo != null;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _fechaPrestamo = ahora;
    _fechaPagoEsperada = ahora.add(const Duration(days: 30));

    final prestamo = widget.prestamo;
    if (prestamo != null) {
      _beneficiarioController.text = prestamo.nombreBeneficiario;
      _montoController.text = AppFormat.montoParaEditar(prestamo.montoPrestado);
      _condicionesController.text = prestamo.condiciones ?? '';
      _observacionesController.text = prestamo.observaciones ?? '';
      _fechaPrestamo = prestamo.fechaPrestamo;
      _fechaPagoEsperada = prestamo.fechaPagoEsperada;
    }
  }

  @override
  void dispose() {
    _beneficiarioController.dispose();
    _montoController.dispose();
    _condicionesController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fechaInvalida = _fechaPagoEsperada.isBefore(_fechaPrestamo);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar préstamo' : 'Nuevo préstamo'),
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
                controller: _beneficiarioController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Beneficiario *',
                  hintText: '¿A quién le prestaste?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre del beneficiario';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                inputFormatters: const [MilesInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Monto prestado *',
                  hintText: 'Ej. 500.000',
                  prefixText: r'$ ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El monto prestado es obligatorio';
                  }
                  final monto = milesADouble(value);
                  if (monto == null || monto <= 0) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _campoFecha(
                titulo: 'Fecha del préstamo *',
                fecha: _fechaPrestamo,
                onTap: () => _seleccionarFecha(esPagoEsperada: false),
              ),
              const SizedBox(height: 12),
              _campoFecha(
                titulo: 'Fecha esperada de pago *',
                fecha: _fechaPagoEsperada,
                onTap: () => _seleccionarFecha(esPagoEsperada: true),
              ),
              if (fechaInvalida) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'La fecha esperada de pago no puede ser anterior a la del préstamo',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _condicionesController,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Condiciones (opcional)',
                  hintText: 'Ej. Interés del 2% mensual, se paga en 6 cuotas',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
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
                  label: Text(
                    _editando ? 'Guardar cambios' : 'Registrar préstamo',
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

  Widget _campoFecha({
    required String titulo,
    required DateTime fecha,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
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
                Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMM yyyy').format(fecha),
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha({required bool esPagoEsperada}) async {
    final hoy = DateTime.now();
    final fechaActual =
        esPagoEsperada ? _fechaPagoEsperada : _fechaPrestamo;
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaActual,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 10),
      helpText: esPagoEsperada ? 'Fecha esperada de pago' : 'Fecha del préstamo',
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
    if (fecha != null) {
      setState(() {
        if (esPagoEsperada) {
          _fechaPagoEsperada = fecha;
        } else {
          _fechaPrestamo = fecha;
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaPagoEsperada.isBefore(_fechaPrestamo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha esperada de pago es anterior a la del préstamo'),
        ),
      );
      return;
    }

    final prestamoActual = widget.prestamo;
    final monto = milesADouble(_montoController.text) ?? 0;

    final prestamo = Loan(
      id: prestamoActual?.id,
      nombreBeneficiario: _beneficiarioController.text.trim(),
      montoPrestado: monto,
      montoPagado: prestamoActual?.montoPagado ?? 0,
      fechaPrestamo: _fechaPrestamo,
      fechaPagoEsperada: _fechaPagoEsperada,
      condiciones: _condicionesController.text.trim().isEmpty
          ? null
          : _condicionesController.text.trim(),
      observaciones: _observacionesController.text.trim().isEmpty
          ? null
          : _observacionesController.text.trim(),
      estado: prestamoActual?.estado ?? 'pendiente',
      fechaCreacion: prestamoActual?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(prestamoRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(prestamo);
      } else {
        await repo.insert(prestamo);
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