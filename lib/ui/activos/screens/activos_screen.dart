import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/asset.dart';
import '../../../logic/activos/activos_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../activos_providers.dart';
import '../../home/tab_navigation.dart';
import 'activo_form_screen.dart';

class ActivosScreen extends ConsumerWidget {
  const ActivosScreen({super.key});

  IconData _iconoParaTipo(String tipo) {
    switch (tipo) {
      case 'cuenta_bancaria':
        return Icons.account_balance_rounded;
      case 'billetera_digital':
        return Icons.account_balance_wallet_rounded;
      case 'efectivo':
        return Icons.money_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'cuenta_bancaria':
        return 'Cuenta bancaria';
      case 'billetera_digital':
        return 'Billetera digital';
      case 'efectivo':
        return 'Efectivo';
      default:
        return 'Otro';
    }
  }

  String _formatearMonto(double monto, String moneda) {
    final symbol = moneda == 'USD' ? 'US\$' : '\$';
    return AppFormat.moneda(monto, symbol: symbol);
  }

  void _abrirFormulario(BuildContext context, WidgetRef ref, {Asset? asset}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivoFormScreen(asset: asset),
      ),
    ).then((_) => ref.invalidate(activosStreamProvider));
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, Asset asset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar activo'),
        content: Text('¿Eliminar "${asset.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(activoRepositoryProvider).delete(asset.id!);
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
              ref.invalidate(activosStreamProvider);
              if (context.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrimonioAsync = ref.watch(patrimonioProvider);
    final patrimonioTotalAsync = ref.watch(patrimonioTotalProvider);
    final activosAsync = ref.watch(activosStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Activos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Column(
        children: [
          _PatrimonioHeader(
            patrimonioPorMoneda: patrimonioAsync,
            patrimonioTotal: patrimonioTotalAsync,
          ),
          Expanded(
            child: activosAsync.when(
              data: (activos) {
                if (activos.isEmpty) {
                  return _EstadoVacio(
                    onAgregar: () => _abrirFormulario(context, ref),
                  );
                }
                return ListView.separated(
                  controller: ref.read(
                    tabScrollControllersProvider,
                  )[TabIndex.activos],
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: activos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final asset = activos[index];
                    return _ActivoCard(
                      asset: asset,
                      icono: _iconoParaTipo(asset.tipo),
                      labelTipo: _labelTipo(asset.tipo),
                      montoFormateado: _formatearMonto(asset.montoDisponible, asset.moneda),
                      onTap: () => _abrirFormulario(context, ref, asset: asset),
                      onEliminar: () => _confirmarEliminar(context, ref, asset),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error al cargar activos: $e',
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
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo activo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }
}

class _PatrimonioHeader extends StatelessWidget {
  final List<PatrimonioPorMoneda> patrimonioPorMoneda;
  final double patrimonioTotal;

  const _PatrimonioHeader({
    required this.patrimonioPorMoneda,
    required this.patrimonioTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patrimonio Total',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormat.moneda(patrimonioTotal),
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnPrimary,
            ),
          ),
          if (patrimonioPorMoneda.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: patrimonioPorMoneda.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${p.moneda}: ${AppFormat.moneda(p.total, symbol: '')}',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
                Icons.account_balance_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes activos registrados',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primera cuenta, billetera o efectivo\npara empezar a ver tu patrimonio.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar activo'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivoCard extends StatelessWidget {
  final Asset asset;
  final IconData icono;
  final String labelTipo;
  final String montoFormateado;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _ActivoCard({
    required this.asset,
    required this.icono,
    required this.labelTipo,
    required this.montoFormateado,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.nombre,
                      style: Theme.of(context).textTheme.titleMedium!,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelTipo,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                montoFormateado,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                onSelected: (value) {
                  if (value == 'eliminar') onEliminar();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'eliminar',
                    child: Text(
                      'Eliminar',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}