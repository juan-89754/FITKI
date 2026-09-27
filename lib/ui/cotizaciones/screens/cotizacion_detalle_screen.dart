import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/quote.dart';
import '../../../data/models/quote_item.dart';
import '../../../logic/cotizaciones/cotizaciones_logic.dart';
import '../cotizaciones_providers.dart';
import 'item_cotizacion_form_screen.dart';

class CotizacionDetalleScreen extends ConsumerWidget {
  final Quote cotizacion;

  const CotizacionDetalleScreen({super.key, required this.cotizacion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsStreamProvider).asData?.value ?? const [];
    final cotizaciones =
        ref.watch(cotizacionesStreamProvider).asData?.value ?? const [];

    Quote actual = cotizacion;
    for (final c in cotizaciones) {
      if (c.id == cotizacion.id) {
        actual = c;
        break;
      }
    }

    final itemsCotizacion = items
        .where((item) => item.cotizacionId == cotizacion.id)
        .toList();
    final total = CotizacionesLogic.totalCotizacion(itemsCotizacion);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de cotización'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar cotización',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _Encabezado(cotizacion: actual),
          const SizedBox(height: 16),
          if (itemsCotizacion.isEmpty)
            _SinItems(
              onAgregar: () => _abrirFormularioItem(context, ref, actual),
            )
          else ...[
            Text(
              'Items',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...itemsCotizacion.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ItemCard(
                  item: item,
                  onTap: () => _abrirFormularioItem(context, ref, actual,
                      item: item),
                  onDelete: () => _eliminarItem(context, ref, item),
                ),
              ),
            ),
            _TotalCard(total: total, items: itemsCotizacion),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioItem(context, ref, actual),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar item'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  void _abrirFormularioItem(
    BuildContext context,
    WidgetRef ref,
    Quote cotizacion, {
    QuoteItem? item,
  }) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ItemCotizacionFormScreen(
              cotizacionId: cotizacion.id!,
              item: item,
            ),
          ),
        )
        .then((guardado) {
      if (guardado == true) ref.invalidate(itemsStreamProvider);
    });
  }

  void _eliminarItem(BuildContext context, WidgetRef ref, QuoteItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar item'),
        content: Text('¿Eliminar "${item.productoServicio}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(itemCotizacionRepositoryProvider)
                    .delete(item.id!);
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
              ref.invalidate(itemsStreamProvider);
              if (ctx.mounted) Navigator.pop(ctx);
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

  void _eliminar(BuildContext context, WidgetRef ref, Quote cotizacion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cotización'),
        content: Text('¿Eliminar "${cotizacion.titulo}" y sus items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(cotizacionRepositoryProvider)
                    .delete(cotizacion.id!);
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
              ref.invalidate(cotizacionesStreamProvider);
              ref.invalidate(itemsStreamProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context, true);
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

class _Encabezado extends StatelessWidget {
  final Quote cotizacion;

  const _Encabezado({required this.cotizacion});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cotizacion.titulo,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPrimary,
              ),
            ),
            if (cotizacion.notas != null && cotizacion.notas!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                cotizacion.notas!,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final QuoteItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productoServicio,
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.cantidad} × ${currency(item.precioUnitario)}',
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onTap,
                  icon: Icon(Icons.edit_rounded,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'Editar item',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.coral),
                  tooltip: 'Eliminar item',
                ),
              ],
            ),
            if (item.costosAdicionales > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.add_box_rounded,
                      size: 14, color: AppColors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Costos adicionales: '
                    '${currency(item.costosAdicionales)}',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
              if (item.costosAdicionalesDetalle.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...item.costosAdicionalesDetalle.map(
                  (costo) => Padding(
                    padding: const EdgeInsets.only(left: 18, top: 2),
                    child: Text(
                      '• ${costo.concepto}: '
                      '${currency(costo.valor)}',
                      style: Theme.of(context).textTheme.bodySmall!,
                    ),
                  ),
                ),
              ],
            ],
            if (item.enlaceCompra != null &&
                item.enlaceCompra!.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.enlaceCompra!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enlace copiado al portapapeles'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.enlaceCompra!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.notas != null && item.notas!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.notas!,
                style: Theme.of(context).textTheme.bodySmall!,
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: ${currency(item.subtotal)}',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final List<QuoteItem> items;

  const _TotalCard({required this.total, required this.items});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    final subtotalItems =
        items.fold<double>(0, (acc, item) => acc + item.subtotal);
    final costos =
        items.fold<double>(0, (acc, item) => acc + item.costosAdicionales);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal items',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                ),
              ),
              Text(
                currency(subtotalItems),
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
          if (costos > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Costos adicionales',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  currency(costos),
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.overlayLight, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total de la cotización',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                ),
              ),
              Text(
                currency(total),
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SinItems extends StatelessWidget {
  final VoidCallback onAgregar;

  const _SinItems({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.mintPale,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin items todavía',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agrega los productos o servicios de\nesta cotización.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar item'),
          ),
        ],
      ),
    );
  }
}