import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/categoria_personalizada.dart';
import '../../../data/models/presupuesto_categoria.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/mixins/guardando_mixin.dart';
import '../presupuesto_providers.dart';

/// Alta y edición del límite de gasto de una categoría en el mes visible.
///
/// Si la categoría tiene historial, la app propone el promedio de los últimos
/// tres meses como punto de partida: un límite realista sale de lo que de
/// verdad se gasta, no de una cifra inventada.
class PresupuestoCategoriaFormScreen extends ConsumerStatefulWidget {
  const PresupuestoCategoriaFormScreen({
    super.key,
    this.categoriaInicial,
    this.presupuesto,
  });

  /// Categoría con la que se abre el formulario (viene de la lista de "sin
  /// presupuesto" de la pantalla principal).
  final String? categoriaInicial;

  /// Presupuesto existente cuando se está editando.
  final PresupuestoCategoria? presupuesto;

  @override
  ConsumerState<PresupuestoCategoriaFormScreen> createState() =>
      _PresupuestoCategoriaFormScreenState();
}

class _PresupuestoCategoriaFormScreenState
    extends ConsumerState<PresupuestoCategoriaFormScreen>
    with GuardandoMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController = TextEditingController(
    text: widget.presupuesto == null
        ? ''
        : AppFormat.montoParaEditar(widget.presupuesto!.montoLimite),
  );

  late String _categoria = widget.presupuesto?.categoria ??
      widget.categoriaInicial ??
      'alimentacion';

  bool get _editando => widget.presupuesto != null;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  /// Categorías que se pueden elegir: las fijas y personalizadas de gasto,
  /// menos las que ya tienen presupuesto este mes (el backstop es el UNIQUE de
  /// la tabla, pero no tiene sentido ofrecer una que va a chocar).
  List<String> _categoriasDisponibles(List<CategoriaPersonalizada> personalizadas) {
    final todas = categoriasDeTipo('gasto', personalizadas);
    if (_editando) return [widget.presupuesto!.categoria];

    final periodo = ref.read(periodoVisibleProvider);
    final presupuestos =
        ref.read(presupuestosCategoriasStreamProvider).asData?.value ??
            const <PresupuestoCategoria>[];
    final yaPresupuestadas = presupuestos
        .where((p) => p.mes == periodo.mes && p.anio == periodo.anio)
        .map((p) => p.categoria)
        .toSet();
    final disponibles =
        todas.where((c) => !yaPresupuestadas.contains(c)).toList();
    return disponibles.isEmpty ? todas : disponibles;
  }

  Future<void> _guardar() => ejecutarGuardado(_guardarReal);

  Future<void> _guardarReal() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = milesADouble(_montoController.text) ?? 0;
    final periodo = ref.read(periodoVisibleProvider);
    final repo = ref.read(presupuestoCategoriaRepositoryProvider);
    final ahora = DateTime.now();

    try {
      final existente = await repo.getByCategoriaYMes(
        _categoria,
        periodo.mes,
        periodo.anio,
      );
      final presupuesto = PresupuestoCategoria(
        id: existente?.id ?? widget.presupuesto?.id,
        categoria: _categoria,
        mes: periodo.mes,
        anio: periodo.anio,
        montoLimite: monto,
        fechaCreacion: existente?.fechaCreacion ?? ahora,
      );

      if (presupuesto.id == null) {
        await repo.insert(presupuesto);
      } else {
        await repo.update(presupuesto);
      }
      ref.invalidate(presupuestosCategoriasStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Quitar el presupuesto?',
      message:
          'Se borra el límite de esta categoría para el mes. Los movimientos '
          'ya registrados no se tocan.',
      confirmLabel: 'Quitar',
      destructive: true,
    );
    if (confirmado != true) return;

    try {
      await ref
          .read(presupuestoCategoriaRepositoryProvider)
          .delete(widget.presupuesto!.id!);
      ref.invalidate(presupuestosCategoriasStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo eliminar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodo = ref.watch(periodoVisibleProvider);
    final personalizadas =
        ref.watch(categoriasPersonalizadasStreamProvider).asData?.value ??
            const <CategoriaPersonalizada>[];
    final categorias = _categoriasDisponibles(personalizadas);
    if (!categorias.contains(_categoria)) {
      _categoria = categorias.first;
    }
    final sugerencia = ref.watch(promedioCategoriaProvider(_categoria));

    return protegerSalida(
      Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_editando ? 'Editar presupuesto' : 'Nuevo presupuesto'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          actions: [
            if (_editando)
              IconButton(
                onPressed: _eliminar,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Quitar presupuesto',
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodo.etiqueta,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('categoria'),
                      initialValue: _categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                      ),
                      items: categorias
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(labelCategoria(c)),
                            ),
                          )
                          .toList(),
                      onChanged: _editando
                          ? null
                          : (v) => setState(() => _categoria = v ?? _categoria),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _montoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [MilesInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Límite de gasto del mes',
                        prefixText: r'$ ',
                        helperText: 'Cuánto quieres gastar en esta categoría',
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final monto = milesADouble(v);
                        if (monto == null || monto <= 0) {
                          return 'Escribe un monto mayor a 0';
                        }
                        return null;
                      },
                    ),
                    if (sugerencia != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mintPale,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'En los últimos 3 meses gastaste en promedio '
                                '${AppFormat.moneda(sugerencia)} al mes en esta '
                                'categoría',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _montoController.text =
                                  AppFormat.montoParaEditar(sugerencia),
                              child: const Text('Usar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No tienes que registrar nada aquí dentro. La app compara '
                  'este límite con los gastos de esta categoría que anotas en '
                  'Movimientos, incluidos los pagos de gastos fijos.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _editando ? 'Guardar cambios' : 'Crear presupuesto',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
