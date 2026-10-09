import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/investment.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../data/repositories/inversion_repository.dart';
import '../../../logic/inversiones/inversiones_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snackbar.dart';

class InversionFormScreen extends ConsumerStatefulWidget {
  final Investment? inversion;

  const InversionFormScreen({super.key, this.inversion});

  @override
  ConsumerState<InversionFormScreen> createState() =>
      _InversionFormScreenState();
}

class _InversionFormScreenState extends ConsumerState<InversionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _tasaController = TextEditingController();
  final _notasController = TextEditingController();

  String _tipo = 'divisas';
  String _periodoTasa = 'anual';
  int? _activoId;
  DateTime _fecha = DateTime.now();

  bool get _editando => widget.inversion != null;

  @override
  void initState() {
    super.initState();
    final inversion = widget.inversion;
    if (inversion != null) {
      _tipo = Investment.tiposValidos.contains(inversion.tipo)
          ? inversion.tipo
          : 'otro';
      _periodoTasa = Investment.periodosValidos.contains(inversion.periodoTasa)
          ? inversion.periodoTasa
          : 'anual';
      _montoController.text =
          AppFormat.montoParaEditar(inversion.montoInvertido);
      _tasaController.text = inversion.tasaRendimiento != null
          ? inversion.tasaRendimiento!.toStringAsFixed(2)
          : '';
      _notasController.text = inversion.notas ?? '';
      _activoId = inversion.activoId;
      _fecha = inversion.fecha;
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _tasaController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar inversión' : 'Nueva inversión'),
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
              _campoTipo(),
              const SizedBox(height: 16),
              _campoActivo(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoController,
                enabled: !_editando,
                keyboardType: TextInputType.number,
                inputFormatters: const [MilesInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Monto invertido *',
                  hintText: 'Ej. 1.000.000',
                  prefixText: r'$ ',
                  helperText: _editando
                      ? 'El capital se gestiona desde el detalle (aportar/retirar).'
                      : null,
                ),
                validator: (value) {
                  if (_editando) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'El monto invertido es obligatorio';
                  }
                  final monto = milesADouble(value);
                  if (monto == null || monto <= 0) {
                    return 'Ingresa un monto válido';
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
                  labelText: 'Tasa de rendimiento % (opcional)',
                  hintText: 'Ej. 12.5',
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
              _campoPeriodoTasa(),
              const SizedBox(height: 16),
              _campoFecha(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notasController,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
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
                    _editando ? 'Guardar cambios' : 'Registrar inversión',
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

  Widget _campoTipo() {
    return DropdownButtonFormField<String>(
      initialValue: _tipo,
      decoration: const InputDecoration(labelText: 'Tipo de inversión'),
      items: Investment.tiposValidos
          .map((tipo) => DropdownMenuItem(
                value: tipo,
                child: Text(InversionesLogic.labelTipo(tipo)),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _tipo = value);
      },
    );
  }

  Widget _campoActivo() {
    final activosAsync = ref.watch(activosStreamProvider);
    return activosAsync.when(
      data: (activos) {
        return DropdownButtonFormField<int?>(
          initialValue: _activoId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Cuenta de origen *',
            helperText: _editando
                ? 'La cuenta no se cambia al editar.'
                : 'El dinero queda reservado desde esta cuenta.',
          ),
          hint: const Text('Elige una cuenta'),
          items: activos
              .map((asset) => DropdownMenuItem<int?>(
                    value: asset.id,
                    child: Text(
                      '${asset.nombre} · ${_formatearSaldo(asset)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: _editando
              ? null
              : (value) => setState(() => _activoId = value),
          validator: (value) {
            if (_editando) return null;
            if (value == null) return 'Elige la cuenta de origen';
            return null;
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Text(
        'Error cargando cuentas: $e',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.coral,
            ),
      ),
    );
  }

  Widget _campoPeriodoTasa() {
    return DropdownButtonFormField<String>(
      initialValue: _periodoTasa,
      decoration: const InputDecoration(labelText: 'Período de la tasa'),
      items: Investment.periodosValidos
          .map((periodo) => DropdownMenuItem(
                value: periodo,
                child: Text(InversionesLogic.labelPeriodo(periodo)),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _periodoTasa = value);
      },
    );
  }

  Widget _campoFecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de la inversión *',
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
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
                Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMM yyyy').format(_fecha),
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

  String _formatearSaldo(Asset asset) {
    final symbol = asset.moneda == 'USD' ? r'US$' : r'$';
    return AppFormat.moneda(asset.montoDisponible, symbol: symbol);
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 5),
      lastDate: hoy,
      helpText: 'Fecha de la inversión',
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
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final inversionActual = widget.inversion;
    final monto = _editando
        ? (inversionActual?.montoInvertido ?? 0)
        : (milesADouble(_montoController.text) ?? 0);
    final tasa = _tasaController.text.trim().isEmpty
        ? null
        : double.tryParse(_tasaController.text.replaceFirst(',', '.'));

    final inversion = Investment(
      id: inversionActual?.id,
      tipo: _tipo,
      activoId: _activoId,
      montoInvertido: monto,
      tasaRendimiento: tasa,
      periodoTasa: _periodoTasa,
      gananciaProyectada: inversionActual?.gananciaProyectada,
      gananciaObtenida: inversionActual?.gananciaObtenida,
      fecha: _fecha,
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
      estado: inversionActual?.estado ?? Investment.estadoActiva,
      fechaCreacion: inversionActual?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(inversionRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(inversion);
      } else {
        await repo.insert(inversion);
      }
    } on OperacionInversionInvalida catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.mensaje,
          type: AppSnackbarType.error,
        );
      }
      return;
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