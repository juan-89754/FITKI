import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/asset.dart';
import '../../../data/models/gasto_fijo.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/forms/activo_obligatorio.dart';
import '../../../shared/theme/app_colors.dart';
import '../presupuesto_providers.dart';

/// Alta y edición de un gasto fijo.
///
/// El activo es obligatorio: se resuelve con la misma regla del resto de la
/// app (si hay uno solo se toma solo; si hay varios hay que elegir).
class GastoFijoFormScreen extends ConsumerStatefulWidget {
  const GastoFijoFormScreen({super.key, this.gasto});

  final GastoFijo? gasto;

  @override
  ConsumerState<GastoFijoFormScreen> createState() =>
      _GastoFijoFormScreenState();
}

class _GastoFijoFormScreenState extends ConsumerState<GastoFijoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();
  final _notasController = TextEditingController();

  String _categoria = 'servicios';
  bool _montoVariable = false;
  bool _habilitado = true;
  int _diaPago = 1;
  int? _activoId;
  DateTime? _fechaFin;

  bool get _editando => widget.gasto != null;

  @override
  void initState() {
    super.initState();
    final gasto = widget.gasto;
    if (gasto != null) {
      _nombreController.text = gasto.nombre;
      _montoController.text = AppFormat.montoParaEditar(gasto.montoEstimado);
      _notasController.text = gasto.notas ?? '';
      _categoria = gasto.categoria;
      _montoVariable = gasto.montoVariable;
      _habilitado = gasto.habilitado;
      _diaPago = gasto.diaPago;
      _activoId = gasto.activoId;
      _fechaFin = gasto.fechaFin;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final activos = ref.read(activosStreamProvider).asData?.value ?? const <Asset>[];
    final activoId = await resolverActivoDeGasto(
      context,
      activos: activos,
      actual: _activoId,
    );
    if (activoId == null) return;

    final monto = milesADouble(_montoController.text) ?? 0;
    final ahora = DateTime.now();
    final gasto = GastoFijo(
      id: widget.gasto?.id,
      nombre: _nombreController.text.trim(),
      categoria: _categoria,
      montoEstimado: monto,
      diaPago: _diaPago,
      activoId: activoId,
      montoVariable: _montoVariable,
      habilitado: _habilitado,
      periodicidad: GastoFijo.periodicidadMensual,
      fechaInicio: widget.gasto?.fechaInicio ?? ahora,
      fechaFin: _fechaFin,
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
      fechaCreacion: widget.gasto?.fechaCreacion ?? ahora,
    );

    final repo = ref.read(gastoFijoRepositoryProvider);
    try {
      if (_editando) {
        await repo.update(gasto);
      } else {
        await repo.insert(gasto);
      }
      ref.invalidate(gastosFijosStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _error('No se pudo guardar, intenta de nuevo');
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${widget.gasto!.nombre}?'),
        content: const Text(
          'Se borra la plantilla y los pagos que dejó registrados. '
          'Los movimientos de dinero que ya se registraron no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await ref.read(gastoFijoRepositoryProvider).delete(widget.gasto!.id!);
      ref.invalidate(gastosFijosStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _error('No se pudo eliminar, intenta de nuevo');
    }
  }

  void _error(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final activos = ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
    final personalizadas =
        ref.watch(categoriasPersonalizadasStreamProvider).asData?.value ??
        const [];
    final categorias = categoriasDeTipo('gasto', personalizadas);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editando ? 'Editar gasto fijo' : 'Nuevo gasto fijo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          if (_editando)
            IconButton(
              onPressed: _eliminar,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Eliminar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Tarjeta(
              titulo: 'Qué es',
              children: [
                TextFormField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Internet, luz, arriendo...',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ponle un nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categorias.contains(_categoria)
                      ? _categoria
                      : categorias.first,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: categorias
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(labelCategoria(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _categoria = v ?? _categoria),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [MilesInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Monto estimado',
                    prefixText: r'$ ',
                    helperText: 'El que esperas pagar este mes',
                  ),
                  validator: (v) {
                    final monto = milesADouble(v);
                    if (monto == null || monto <= 0) {
                      return 'Escribe un monto mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _montoVariable,
                  onChanged: (v) => setState(() => _montoVariable = v),
                  title: const Text('El precio cambia cada mes'),
                  subtitle: const Text(
                    'Al pagar se te precarga un estimado (el promedio de los '
                    'últimos pagos) para que lo corrijas si cambió',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Tarjeta(
              titulo: 'Cuándo y desde dónde',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _diaPago,
                        decoration: const InputDecoration(
                          labelText: 'Día de pago',
                        ),
                        items: [
                          for (var d = 1; d <= 31; d++)
                            DropdownMenuItem(value: d, child: Text('$d')),
                        ],
                        onChanged: (v) =>
                            setState(() => _diaPago = v ?? _diaPago),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sale de',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (activos.isEmpty)
                  const _Aviso(
                    texto:
                        'No tienes activos. Crea una cuenta en Activos para '
                        'poder registrar este gasto.',
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final activo in activos)
                        ChoiceChip(
                          label: Text(activo.nombre),
                          selected: _activoId == activo.id,
                          onSelected: (_) =>
                              setState(() => _activoId = activo.id),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ahora = DateTime.now();
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin ?? ahora,
                      firstDate: DateTime(ahora.year, ahora.month),
                      lastDate: DateTime(ahora.year + 10),
                      helpText: 'Termina en',
                    );
                    if (fecha != null) setState(() => _fechaFin = fecha);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _fechaFin == null
                        ? 'Sin fecha de fin'
                        : 'Termina el ${DateFormat('d/M/y').format(_fechaFin!)}',
                  ),
                ),
                if (_fechaFin != null)
                  TextButton(
                    onPressed: () => setState(() => _fechaFin = null),
                    child: const Text('Quitar fecha de fin'),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _habilitado,
                  onChanged: (v) => setState(() => _habilitado = v),
                  title: const Text('Activo'),
                  subtitle: const Text(
                    'Al desactivarlo deja de generar pagos, sin borrar lo ya '
                    'registrado',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notasController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    hintText: 'Opcional',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_editando ? 'Guardar cambios' : 'Crear gasto fijo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chipBackgroundOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
      ),
    );
  }
}
