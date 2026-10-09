import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/categoria_personalizada.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../presupuesto/presupuesto_providers.dart';

/// Gestión de categorías personalizadas de gasto/ingreso. Las categorías se
/// guardan por NOMBRE (ese nombre queda como `categoria` en los movimientos y
/// gastos fijos) y los íconos se eligen de una lista predefinida.
///
/// DECISIÓN sobre categorías borradas: al eliminar una categoría, los
/// movimientos/gastos fijos que la usaban se reasignan a [categoriaEliminada].
/// El historial no se pierde ni se rompe: en las pantallas aparece como
/// "Categoría eliminada" (ver labelCategoria) y el dropdown ya no la ofrece.
class CategoriasScreen extends ConsumerStatefulWidget {
  const CategoriasScreen({super.key});

  @override
  ConsumerState<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends ConsumerState<CategoriasScreen> {
  Future<void> _agregarCategoria() async {
    final personalizadas = ref
        .read(categoriasPersonalizadasStreamProvider)
        .value ??
        const <CategoriaPersonalizada>[];
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormCategoriaSheet(
        existentes: personalizadas,
        onGuardar: (nombre, icono, tipo) async {
          try {
            final repo = ref.read(categoriaPersonalizadaRepositoryProvider);
            await repo.insert(
              CategoriaPersonalizada(
                nombre: nombre,
                icono: icono,
                tipo: tipo,
              ),
            );
            ref.invalidate(categoriasPersonalizadasStreamProvider);
          } catch (_) {
            if (mounted) {
              AppSnackbar.show(
                context,
                message: 'No se pudo guardar, intenta de nuevo',
                type: AppSnackbarType.error,
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmarEliminar(CategoriaPersonalizada categoria) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Eliminar categoría',
      message:
          'Se eliminará "${categoria.nombre}". Los movimientos y presupuestos '
          'que la usan se mantendrán y se mostrarán como "Categoría '
          'eliminada".',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmado != true || !mounted) return;

    try {
      final movRepo = ref.read(movimientoRepositoryProvider);
      final gastoFijoRepo = ref.read(gastoFijoRepositoryProvider);
      final catRepo = ref.read(categoriaPersonalizadaRepositoryProvider);
      // Reasignar el historial antes de borrar la fila, para que nada quede
      // apuntando a una categoría inexistente.
      await movRepo.actualizarCategoria(categoria.nombre, categoriaEliminada);
      await gastoFijoRepo.actualizarCategoria(
        categoria.nombre,
        categoriaEliminada,
      );
      await catRepo.delete(categoria.id!);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo eliminar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }
    ref.invalidate(categoriasPersonalizadasStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasPersonalizadasStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Categorías'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarCategoria,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        child: const Icon(Icons.add_rounded),
      ),
      body: categoriasAsync.when(
        data: (categorias) {
          if (categorias.isEmpty) {
            return const _EstadoVacioCategorias();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: categorias.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final categoria = categorias[index];
              return _CategoriaCard(
                categoria: categoria,
                onEliminar: () => _confirmarEliminar(categoria),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar categorías: $e',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.coral,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final CategoriaPersonalizada categoria;
  final VoidCallback onEliminar;

  const _CategoriaCard({required this.categoria, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final esGasto = categoria.tipo == 'gasto';
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: esGasto
                    ? AppColors.coral.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconoPersonalizado(categoria.icono),
                color: esGasto ? AppColors.coral : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria.nombre,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: esGasto
                              ? AppColors.chipBackgroundCoral
                              : AppColors.chipBackgroundPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          esGasto ? 'Gasto' : 'Ingreso',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: esGasto ? AppColors.coral : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEliminar,
              tooltip: 'Eliminar categoría',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.coral,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacioCategorias extends StatelessWidget {
  const _EstadoVacioCategorias();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.mintPale,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.category_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes categorías personalizadas. Pulsa + para crear '
              'la primera: se sumará a los dropdowns de gasto e ingreso.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium!,
            ),
          ],
        ),
      ),
    );
  }
}

/// Íconos disponibles para categorías personalizadas. Se guarda el NOMBRE del
/// ícono (texto estable a salvo de versiones del SDK) y la UI lo resuelve aquí.
const Map<String, IconData> _iconosDisponibles = {
  'restaurant_rounded': Icons.restaurant_rounded,
  'local_cafe_rounded': Icons.local_cafe_rounded,
  'shopping_cart_rounded': Icons.shopping_cart_rounded,
  'directions_bus_rounded': Icons.directions_bus_rounded,
  'commute_rounded': Icons.commute_rounded,
  'home_rounded': Icons.home_rounded,
  'lightbulb_rounded': Icons.lightbulb_rounded,
  'school_rounded': Icons.school_rounded,
  'local_hospital_rounded': Icons.local_hospital_rounded,
  'fitness_center_rounded': Icons.fitness_center_rounded,
  'pets_rounded': Icons.pets_rounded,
  'checkroom_rounded': Icons.checkroom_rounded,
  'devices_rounded': Icons.devices_rounded,
  'sports_esports_rounded': Icons.sports_esports_rounded,
  'card_giftcard_rounded': Icons.card_giftcard_rounded,
};

/// Resuelve el nombre guardado a su [IconData]; ícono genérico si no se
/// encuentra (datos de una versión anterior, por ejemplo).
IconData iconoPersonalizado(String nombre) {
  return _iconosDisponibles[nombre] ?? Icons.category_rounded;
}

class _FormCategoriaSheet extends StatefulWidget {
  /// Categorías ya existentes, para bloquear duplicados al guardar.
  final List<CategoriaPersonalizada> existentes;

  /// Inserta la categoría; recibe (nombre, nombreDeIcono, tipo).
  final Future<void> Function(String nombre, String icono, String tipo)
      onGuardar;

  const _FormCategoriaSheet({required this.existentes, required this.onGuardar});

  @override
  State<_FormCategoriaSheet> createState() => _FormCategoriaSheetState();
}

class _FormCategoriaSheetState extends State<_FormCategoriaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  String _tipo = 'gasto';
  String _icono = 'restaurant_rounded';
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  String? _validarNombre(String? value) {
    final nombre = value?.trim() ?? '';
    if (nombre.isEmpty) return 'Escribe el nombre de la categoría';

    final base = nombre.toLowerCase();
    final duplicado = widget.existentes.any(
      (c) => c.nombre.toLowerCase() == base,
    );
    final esFija = categoriasGasto.any(
          (c) => c.toLowerCase() == base,
        ) ||
        categoriasIngreso.any((c) => c.toLowerCase() == base);
    if (duplicado || esFija) {
      return 'Ya existe una categoría con ese nombre';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        bottomInset + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva categoría',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aparecerá en los dropdowns de categoría según su tipo.',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej: Mascotas, Gimnasio, Becas',
                ),
                validator: _validarNombre,
              ),
              const SizedBox(height: 16),
              Text(
                'Tipo',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
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
                  ),
                ],
                selected: {_tipo},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _tipo = selection.first);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Ícono',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _iconosDisponibles.entries.map((entry) {
                  final seleccionado = entry.key == _icono;
                  return InkWell(
                    onTap: () => setState(() => _icono = entry.key),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: seleccionado
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: seleccionado
                              ? AppColors.primary
                              : AppColors.borderSubtle,
                          width: seleccionado ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        color: seleccionado
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _guardando = true);
                        await widget.onGuardar(
                          _nombreController.text.trim(),
                          _icono,
                          _tipo,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _guardando ? 'Guardando...' : 'Crear categoría',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}