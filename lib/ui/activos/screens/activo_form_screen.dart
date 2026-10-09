import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../data/models/abono_meta.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/investment.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/activos/activos_logic.dart';
import '../../metas/metas_providers.dart';
import '../../prestamos_inversiones/prestamos_inversiones_providers.dart';

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

  /// Dinero de esta cuenta que está reservado en metas.
  ///
  /// El formulario es el único lugar donde el saldo de un activo se escribe a
  /// mano, así que es también donde se valida que ese saldo siga cubriendo las
  /// reservas existentes: si no, el Saldo Disponible quedaría negativo sin que
  /// nadie lo hubiera decidido.
  double get _reservado {
    final registros =
        ref.read(registrosDeMetasProvider).asData?.value ??
        const <AbonoMeta>[];
    final inversiones =
        ref.read(inversionesStreamProvider).asData?.value ??
        const <Investment>[];
    return ActivosLogic.saldoReservadoEn(widget.asset?.id, registros) +
        ActivosLogic.saldoReservadoInversionesEn(widget.asset?.id, inversiones);
  }

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
                    decoration: InputDecoration(
                      labelText: 'Monto disponible *',
                      hintText: 'Ej. 3.000.000',
                      helperMaxLines: 2,
                      // Escribir el saldo a mano es la excepción, no la regla,
                      // pero sigue siendo la forma más fácil de dejar la cuenta
                      // descuadrada sin darse cuenta. Si hay reservas, se avisa de
                      // que el campo es el Saldo Total y de que el disponible es
                      // otro.
                      helperText: _reservado > 0
                          ? 'Es el saldo total de la cuenta. Tienes '
                                '${AppFormat.moneda(_reservado)} reservados en '
                                'metas, así que solo podrás gastar '
                                '${AppFormat.moneda((milesADouble(_montoController.text) ?? 0) - _reservado)}.'
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      final monto = milesADouble(value);
                      if (monto == null || monto <= 0) {
                        return 'Monto debe ser > 0';
                      }
                      // No se puede dejar el saldo total por debajo de lo que ya
                      // está apartado: eso haría disponible negativo sin que
                      // nadie haya autorizado ese negativo.
                      if (monto < _reservado) {
                        return 'Hay ${AppFormat.moneda(_reservado)} reservados '
                            'en metas. El saldo no puede ser menor.';
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
                      if (value != null) {
                        setState(() => _monedaSeleccionada = value);
                      }
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