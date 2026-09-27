import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/asset.dart';
import '../../../data/providers/shared_providers.dart';

class ActivoFormScreen extends ConsumerStatefulWidget {
  final Asset? asset;

  const ActivoFormScreen({super.key, this.asset});

  @override
  ConsumerState<ActivoFormScreen> createState() => _ActivoFormScreenState();
}

class _ActivoFormScreenState extends ConsumerState<ActivoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  String _tipoSeleccionado = 'cuenta_bancaria';
  String _monedaSeleccionada = 'COP';

  static const List<String> _tipos = [
    'cuenta_bancaria',
    'billetera_digital',
    'efectivo',
    'otro',
  ];

  static const List<String> _monedas = ['COP', 'USD', 'EUR'];

  final Map<String, String> _labelsTipo = const {
    'cuenta_bancaria': 'Cuenta bancaria',
    'billetera_digital': 'Billetera digital',
    'efectivo': 'Efectivo',
    'otro': 'Otro',
  };

  final Map<String, IconData> _iconosTipo = const {
    'cuenta_bancaria': Icons.account_balance_rounded,
    'billetera_digital': Icons.account_balance_wallet_rounded,
    'efectivo': Icons.money_rounded,
    'otro': Icons.category_rounded,
  };

  @override
  void initState() {
    super.initState();
    if (widget.asset != null) {
      _nombreController.text = widget.asset!.nombre;
      _tipoSeleccionado = widget.asset!.tipo;
      _montoController.text =
          AppFormat.montoParaEditar(widget.asset!.montoDisponible);
      _monedaSeleccionada = widget.asset!.moneda;
      _descripcionController.text = widget.asset!.descripcion ?? '';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.asset != null;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final asset = Asset(
      id: widget.asset?.id,
      nombre: _nombreController.text.trim(),
      tipo: _tipoSeleccionado,
      montoDisponible: milesADouble(_montoController.text) ?? 0,
      moneda: _monedaSeleccionada,
      descripcion: _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
      fechaCreacion: widget.asset?.fechaCreacion ?? DateTime.now(),
    );

    final repo = ref.read(activoRepositoryProvider);
    try {
      if (_isEditing) {
        await repo.update(asset);
      } else {
        await repo.insert(asset);
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
        title: Text(_isEditing ? 'Editar activo' : 'Nuevo activo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej: Cuenta ahorros, Nequi, Efectivo',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipoSeleccionado,
              decoration: const InputDecoration(labelText: 'Tipo *'),
              items: _tipos.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Row(
                    children: [
                      Icon(
                        _iconosTipo[tipo]!,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_labelsTipo[tipo]!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _tipoSeleccionado = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _montoController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [MilesInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Monto disponible *',
                      hintText: 'Ej. 3.000.000',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      final monto = milesADouble(value);
                      if (monto == null || monto <= 0) {
                        return 'Monto debe ser > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _monedaSeleccionada,
                    decoration: const InputDecoration(labelText: 'Moneda *'),
                    items: _monedas
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _monedaSeleccionada = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Notas adicionales...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isEditing ? 'Guardar cambios' : 'Crear activo',
                style: Theme.of(context).textTheme.titleMedium!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}