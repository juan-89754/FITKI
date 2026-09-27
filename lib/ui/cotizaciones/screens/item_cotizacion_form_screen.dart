import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/quote_item.dart';
import '../cotizaciones_providers.dart';

class _FilaCosto {
  final TextEditingController concepto;
  final TextEditingController valor;

  _FilaCosto({String concepto = '', String valor = ''})
      : concepto = TextEditingController(text: concepto),
        valor = TextEditingController(text: valor);

  void dispose() {
    concepto.dispose();
    valor.dispose();
  }
}

class ItemCotizacionFormScreen extends ConsumerStatefulWidget {
  final int cotizacionId;
  final QuoteItem? item;

  const ItemCotizacionFormScreen({
    super.key,
    required this.cotizacionId,
    this.item,
  });

  @override
  ConsumerState<ItemCotizacionFormScreen> createState() =>
      _ItemCotizacionFormScreenState();
}

class _ItemCotizacionFormScreenState
    extends ConsumerState<ItemCotizacionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();
  final _enlaceController = TextEditingController();
  final _notasController = TextEditingController();
  final List<_FilaCosto> _costos = [];
  String _tipoItem = QuoteItem.tipoProducto;

  bool get _editando => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _tipoItem = item.tipo;
      _productoController.text = item.productoServicio;
      _cantidadController.text = item.cantidad.toString();
      _precioController.text = AppFormat.montoParaEditar(item.precioUnitario);
      _enlaceController.text = item.enlaceCompra ?? '';
      _notasController.text = item.notas ?? '';
      if (item.costosAdicionalesDetalle.isNotEmpty) {
        for (final costo in item.costosAdicionalesDetalle) {
          _costos.add(_FilaCosto(
            concepto: costo.concepto,
            valor: AppFormat.montoParaEditar(costo.valor),
          ));
        }
      } else if (item.costosAdicionales > 0) {
        _costos.add(_FilaCosto(
          concepto: 'Costos adicionales',
          valor: AppFormat.montoParaEditar(item.costosAdicionales),
        ));
      }
    }
  }

  @override
  void dispose() {
    _productoController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _enlaceController.dispose();
    _notasController.dispose();
    for (final costo in _costos) {
      costo.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar item' : 'Agregar item'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _productoController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Producto / servicio *',
                    hintText: 'Ej. Laptop 16GB',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el producto o servicio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _tipoItem,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de item *',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: QuoteItem.tipoProducto,
                      child: Text('Producto'),
                    ),
                    DropdownMenuItem(
                      value: QuoteItem.tipoServicio,
                      child: Text('Servicio'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _tipoItem = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cantidadController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cantidad *',
                        ),
                        validator: (value) {
                          final cantidad = int.tryParse(value ?? '');
                          if (cantidad == null || cantidad < 1) {
                            return 'Mínimo 1';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _precioController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [MilesInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Precio unitario *',
                          hintText: 'Ej. 3.500.000',
                          prefixText: r'$ ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          final precio = milesADouble(value);
                          if (precio == null || precio <= 0) {
                            return 'Debe ser > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _enlaceController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: _tipoItem == QuoteItem.tipoProducto
                        ? 'Enlace de compra (opcional)'
                        : 'Enlace de compra (opcional)',
                    hintText: _tipoItem == QuoteItem.tipoProducto
                        ? 'https://... (busca el producto para comparar precios)'
                        : 'https://...',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _tipoItem == QuoteItem.tipoServicio
                        ? 'Notas *'
                        : 'Notas (opcional)',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (_tipoItem == QuoteItem.tipoServicio &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Las notas son obligatorias para servicios';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _seccionCostosAdicionales(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.check_rounded),
              label: Text(_editando ? 'Guardar cambios' : 'Agregar item'),
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
    );
  }

  Widget _seccionCostosAdicionales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Costos adicionales',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => _costos.add(_FilaCosto()));
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        if (_costos.isEmpty)
          Text(
            'Ej. Importación, tasas, embalaje... (opcional)',
            style: Theme.of(context).textTheme.bodySmall!,
          )
        else
          ..._costos.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: entry.value.concepto,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Concepto',
                            hintText: 'Ej. Importación',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: entry.value.valor,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [MilesInputFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Valor',
                            hintText: 'Ej. 120.000',
                            prefixText: r'$ ',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            entry.value.dispose();
                            _costos.removeAt(entry.key);
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.coral,
                          size: 20,
                        ),
                        tooltip: 'Quitar costo',
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tipoItem == QuoteItem.tipoServicio &&
        _notasController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para servicios, las notas son obligatorias'),
          ),
        );
      }
      return;
    }

    final detalle = <CostoAdicional>[];
    int omitidas = 0;
    double costosSuma = 0;
    for (final fila in _costos) {
      final concepto = fila.concepto.text.trim();
      final valor = milesADouble(fila.valor.text);
      if (concepto.isNotEmpty && valor != null && valor > 0) {
        detalle.add(CostoAdicional(concepto: concepto, valor: valor));
        costosSuma += valor;
      } else {
        omitidas++;
      }
    }

    if (omitidas > 0) {
      final continuar = await _confirmarOmitidas(omitidas);
      if (!continuar) return;
    }

    final actual = widget.item;
    final item = QuoteItem(
      id: actual?.id,
      cotizacionId: actual?.cotizacionId ?? widget.cotizacionId,
      productoServicio: _productoController.text.trim(),
      tipo: _tipoItem,
      cantidad: int.tryParse(_cantidadController.text) ?? 1,
      precioUnitario: milesADouble(_precioController.text) ?? 0,
      enlaceCompra: _enlaceController.text.trim().isEmpty
          ? null
          : _enlaceController.text.trim(),
      costosAdicionales: costosSuma,
      costosAdicionalesDetalle: detalle,
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
    );

    final repo = ref.read(itemCotizacionRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(item);
      } else {
        await repo.insert(item);
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

  Future<bool> _confirmarOmitidas(int cantidad) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Costos adicionales incompletos'),
        content: Text(
          cantidad == 1
              ? '1 fila de costos adicionales no se guardará por estar '
                  'incompleta (concepto vacío o valor inválido).\n\n'
                  '¿Continuar y guardar las filas válidas?'
              : '$cantidad filas de costos adicionales no se guardarán por '
                  'estar incompletas (concepto vacío o valor inválido).\n\n'
                  '¿Continuar y guardar las filas válidas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return continuar ?? false;
  }
}