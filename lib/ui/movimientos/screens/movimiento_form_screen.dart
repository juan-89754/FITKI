import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/forms/activo_obligatorio.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/categoria_personalizada.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../data/providers/shared_providers.dart';

class MovimientoFormScreen extends ConsumerStatefulWidget {
  final Transaction? movimiento;

  const MovimientoFormScreen({super.key, this.movimiento});

  @override
  ConsumerState<MovimientoFormScreen> createState() =>
      _MovimientoFormScreenState();
}

class _MovimientoFormScreenState extends ConsumerState<MovimientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _notaController = TextEditingController();

  String _tipo = 'gasto';
  String _categoria = 'alimentacion';
  int? _activoId;
  late DateTime _fecha;

  final DateFormat _fechaFormat = DateFormat('dd MMM yyyy');

  bool get _isEditing => widget.movimiento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    if (m != null) {
      _tipo = m.tipo;
      _categoria = m.categoria;
      _montoController.text = AppFormat.montoParaEditar(m.monto);
      _activoId = m.activoId;
      _fecha = m.fecha;
      _notaController.text = m.nota ?? '';
    } else {
      _fecha = DateTime.now();
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  /// Opciones del dropdown de categoría: fijas del tipo vigente + las
  /// personalizadas del usuario (ver categoriasDeTipo). Si el movimiento en
  /// edición usa una categoría que ya no existe (p. ej. una personalizada
  /// borrada), se agrega como opción para que la selección siga visible.
  List<String> _opcionesCategoria() {
    final personalizadas = ref
        .read(categoriasPersonalizadasStreamProvider)
        .value ??
        const <CategoriaPersonalizada>[];
    final categorias = categoriasDeTipo(_tipo, personalizadas);
    if (categorias.contains(_categoria)) return categorias;
    return [...categorias, _categoria];
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 5),
      lastDate: DateTime(ahora.year + 1, 12, 31),
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
    if (seleccionada != null) {
      setState(() => _fecha = seleccionada);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Todo gasto tiene que salir de una cuenta: es lo que hace que el
    // presupuesto por activo sume bien. Si hay una sola, se usa sola; si hay
    // varias y no eligió, se pregunta.
    if (_tipo == Transaction.tipoGasto) {
      final activos =
          ref.read(activosStreamProvider).asData?.value ?? const <Asset>[];
      final activoId = await resolverActivoDeGasto(
        context,
        activos: activos,
        actual: _activoId,
      );
      if (activoId == null) return;
      _activoId = activoId;
    }

    final monto = milesADouble(_montoController.text) ?? 0;
    final nuevo = Transaction(
      id: widget.movimiento?.id,
      tipo: _tipo,
      monto: monto,
      categoria: _categoria,
      fecha: _fecha,
      activoId: _activoId,
      nota: _notaController.text.trim().isEmpty
          ? null
          : _notaController.text.trim(),
      fechaCreacion: widget.movimiento?.fechaCreacion ?? DateTime.now(),
    );

    try {
      final movRepo = ref.read(movimientoRepositoryProvider);

      final original = widget.movimiento;
      if (_isEditing && original != null) {
        await movRepo.actualizarConAjusteDeSaldo(
          original: original,
          nuevo: nuevo,
        );
      } else {
        // El saldo lo descuenta el propio repositorio, en la misma
        // transacción que guarda el movimiento.
        await movRepo.insert(nuevo);
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
    final activosAsync = ref.watch(activosStreamProvider);
    // Suscripción reactiva: si el usuario crea/borra categorías, el dropdown
    // se reconstruye con la lista actualizada.
    ref.watch(categoriasPersonalizadasStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSelectorTipo(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              inputFormatters: const [MilesInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Monto *',
                hintText: 'Ej. 1.500.000',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: _tipo == 'ingreso'
                      ? AppColors.primary
                      : AppColors.coral,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El monto es obligatorio';
                }
                final monto = milesADouble(value);
                if (monto == null || monto <= 0) {
                  return 'El monto debe ser mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría *'),
              items: _opcionesCategoria().map((categoria) {
                return DropdownMenuItem(
                  value: categoria,
                  child: Text(labelCategoria(categoria)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _categoria = value);
              },
            ),
            const SizedBox(height: 16),
            activosAsync.when(
              data: (activos) {
                return DropdownButtonFormField<int?>(
                  initialValue: _activoId,
                  decoration: const InputDecoration(labelText: 'Activo'),
                  hint: const Text('Sin activo'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sin activo'),
                    ),
                    ...activos.map((asset) => DropdownMenuItem<int?>(
                          value: asset.id,
                          child: Text(
                            '${asset.nombre} (${_formatearSaldo(asset)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) => setState(() => _activoId = value),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                'Error cargando activos: $e',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppColors.coral,
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha *'),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _fechaFormat.format(_fecha),
                      style: Theme.of(context).textTheme.titleSmall!,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _categoria == 'otro'
                  ? TextFormField(
                      key: const ValueKey('especificar-otro'),
                      controller: _notaController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Especifica qué fue *',
                        hintText: 'Detalle del ingreso o gasto',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Especifica qué fue este movimiento';
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      key: const ValueKey('nota-opcional'),
                      controller: _notaController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Nota (opcional)',
                        hintText: 'Detalles adicionales...',
                        alignLabelWithHint: true,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: _tipo == 'ingreso'
                    ? AppColors.primary
                    : AppColors.coral,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isEditing ? 'Guardar cambios' : 'Registrar movimiento',
                style: Theme.of(context).textTheme.titleMedium!,
              ),
            ),
            if (_activoId != null) ...[
              const SizedBox(height: 12),
              Text(
                _tipo == 'ingreso'
                    ? 'Se sumará al saldo del activo seleccionado.'
                    : 'Se descontará del saldo del activo seleccionado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorTipo() {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'gasto',
          label: Text(
            'Gasto',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: _tipo == 'gasto'
                      ? AppColors.coral
                      : AppColors.textSecondary,
                ),
          ),
          icon: Icon(
            Icons.arrow_upward_rounded,
            size: 18,
            color: _tipo == 'gasto' ? AppColors.coral : AppColors.textSecondary,
          ),
        ),
        ButtonSegment(
          value: 'ingreso',
          label: Text(
            'Ingreso',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: _tipo == 'ingreso'
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
          ),
          icon: Icon(
            Icons.arrow_downward_rounded,
            size: 18,
            color: _tipo == 'ingreso'
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ],
      selected: {_tipo},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _tipo = selection.first;
          // Reinicio síncrono a una categoría fija del nuevo tipo; el
          // dropdown gasto/ingreso siempre la incluye y luego se rellena
          // con las personalizadas del tipo desde el stream provider.
          _categoria = _tipo == 'ingreso' ? 'salario' : 'alimentacion';
        });
      },
    );
  }

  String _formatearSaldo(Asset asset) {
    final symbol = asset.moneda == 'USD' ? r'US$' : r'$';
    return AppFormat.moneda(asset.montoDisponible, symbol: symbol);
  }
}