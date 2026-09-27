import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/asset.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/movimientos/movimientos_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../movimientos_providers.dart';
import '../../home/tab_navigation.dart';
import 'movimiento_form_screen.dart';

class MovimientosScreen extends ConsumerStatefulWidget {
  const MovimientosScreen({super.key});

  @override
  ConsumerState<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends ConsumerState<MovimientosScreen> {
  String? _filtroTipo;

  static const List<String> _filtros = ['todos', 'ingreso', 'gasto'];

  @override
  Widget build(BuildContext context) {
    final movimientosAsync = ref.watch(movimientosStreamProvider);
    final activosAsync = ref.watch(activosStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Movimientos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: movimientosAsync.when(
              data: (movimientos) {
                final filtrados = _filtroTipo == null
                    ? movimientos
                    : movimientos
                        .where((m) => m.tipo == _filtroTipo)
                        .toList();
                final activos = activosAsync.asData?.value ?? const <Asset>[];
                return Column(
                  children: [
                    _ResumenBalance(movimientos: movimientos),
                    Expanded(
                      child: filtrados.isEmpty
                          ? _EstadoVacio(
                              onAgregar: () => _abrirFormulario(context),
                            )
                          : ListView.separated(
                              controller: ref
                                  .read(tabScrollControllersProvider)[
                                    TabIndex.movimientos
                                  ],
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: filtrados.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, index) {
                                final movimiento = filtrados[index];
                                return _MovimientoCard(
                                  movimiento: movimiento,
                                  asset: _buscarActivo(activos, movimiento.activoId),
                                  onTap: () =>
                                      _abrirFormulario(context, movimiento: movimiento),
                                  onEliminar: () =>
                                      _confirmarEliminar(context, movimiento),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar movimientos: $e',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: AppColors.coral,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo movimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: _filtros.map((filtro) {
          final label = switch (filtro) {
            'todos' => 'Todos',
            'ingreso' => 'Ingresos',
            _ => 'Gastos',
          };
          final selected = _filtroTipo == filtro ||
              (_filtroTipo == null && filtro == 'todos');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() {
                _filtroTipo = filtro == 'todos' ? null : filtro;
              }),
              selectedColor: AppColors.mintPale,
              labelStyle: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontSize: 13,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              side: BorderSide.none,
              backgroundColor: AppColors.surfaceSecondary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Asset? _buscarActivo(List<Asset> activos, int? activoId) {
    if (activoId == null) return null;
    for (final asset in activos) {
      if (asset.id == activoId) return asset;
    }
    return null;
  }

  void _abrirFormulario(BuildContext context, {Transaction? movimiento}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => MovimientoFormScreen(movimiento: movimiento),
      ),
    )
        .then((guardado) {
      if (guardado == true) {
        ref.invalidate(movimientosStreamProvider);
        ref.invalidate(activosStreamProvider);
      }
    });
  }

  void _confirmarEliminar(BuildContext context, Transaction movimiento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text(
          '¿Eliminar ${movimiento.categoria} por ${AppFormat.moneda(movimiento.monto)}?'
          '\nSe revertirá el saldo del activo asociado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                // El repositorio borra el movimiento y devuelve el monto al
                // saldo de su activo en la misma transacción.
                await ref
                    .read(movimientoRepositoryProvider)
                    .delete(movimiento.id!);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo eliminar, intenta de nuevo'),
                    ),
                  );
                }
                return;
              }
              ref.invalidate(movimientosStreamProvider);
              ref.invalidate(activosStreamProvider);
              if (context.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _ResumenBalance extends StatelessWidget {
  final List<Transaction> movimientos;

  const _ResumenBalance({required this.movimientos});

  @override
  Widget build(BuildContext context) {
    final ingresos = MovimientosLogic.totalIngresos(movimientos);
    final gastos = MovimientosLogic.totalGastos(movimientos);
    final balance = MovimientosLogic.balanceNeto(movimientos);
    const currency = AppFormat.moneda;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          _ColumnaResumen(
            label: 'Ingresos',
            value: currency(ingresos),
            color: AppColors.primary,
          ),
          _separador(),
          _ColumnaResumen(
            label: 'Gastos',
            value: currency(gastos),
            color: AppColors.coral,
          ),
          _separador(),
          _ColumnaResumen(
            label: 'Balance',
            value: currency(balance),
            color: balance >= 0 ? AppColors.primary : AppColors.coral,
          ),
        ],
      ),
    );
  }

  Widget _separador() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.borderSubtle,
    );
  }
}

class _ColumnaResumen extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ColumnaResumen({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final VoidCallback onAgregar;

  const _EstadoVacio({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icons.swap_horiz_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay movimientos',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra tu primer ingreso o gasto\npara comenzar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar movimiento'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimientoCard extends StatelessWidget {
  final Transaction movimiento;
  final Asset? asset;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _MovimientoCard({
    required this.movimiento,
    required this.asset,
    required this.onTap,
    required this.onEliminar,
  });

  bool get _esIngreso => movimiento.tipo == 'ingreso';
  Color get _color => _esIngreso ? AppColors.primary : AppColors.coral;

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onTap();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: AppColors.coral),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onEliminar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaFormateada = DateFormat('dd MMM yyyy').format(movimiento.fecha);
    final moneda = asset?.moneda ?? 'COP';
    final symbol = moneda == 'USD' ? r'US$' : r'$';

    return GestureDetector(
      onLongPress: () => _mostrarOpciones(context),
      child: Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _esIngreso
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: _color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelCategoria(movimiento.categoria),
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          fechaFormateada,
                          if (asset != null) ' · ${asset!.nombre}',
                        ].join(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall!,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_esIngreso ? '+' : '-'}${AppFormat.moneda(movimiento.monto, symbol: symbol)}',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}