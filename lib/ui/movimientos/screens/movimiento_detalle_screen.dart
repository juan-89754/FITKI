import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/asset.dart';
import '../../../logic/categorias/categoria_labels.dart';

class MovimientoDetalleScreen extends StatelessWidget {
  final Transaction movimiento;
  final Asset? asset;

  const MovimientoDetalleScreen({
    super.key,
    required this.movimiento,
    this.asset,
  });

  bool get _esIngreso => movimiento.tipo == Transaction.tipoIngreso;

  Color get _color => _esIngreso ? AppColors.primary : AppColors.coral;

  @override
  Widget build(BuildContext context) {
    final fechaFormateada = DateFormat('dd/MM/yyyy').format(movimiento.fecha);
    final moneda = asset?.moneda ?? 'COP';
    final symbol = moneda == 'USD' ? r'US$' : r'$';
    final nota = movimiento.nota?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalles del movimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _esIngreso
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: _color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelCategoria(movimiento.categoria),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _esIngreso ? 'Ingreso' : 'Gasto',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DetalleItem(
                        icon: Icons.attach_money_rounded,
                        label: 'Monto',
                        value:
                            '${_esIngreso ? '+' : '-'}${AppFormat.moneda(movimiento.monto, symbol: symbol)}',
                        valueColor: _color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetalleItem(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Activo/Cuenta',
                        value: asset?.nombre ?? 'Sin activo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetalleItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Fecha',
                  value: fechaFormateada,
                ),
                const SizedBox(height: 12),
                _DetalleItem(
                  icon: Icons.note_alt_outlined,
                  label: 'Nota',
                  value: (nota == null || nota.isEmpty) ? '-' : nota,
                  maxLines: null,
                ),
              ],
            ),
          ),
          if (movimiento.comprobantePath != null &&
              movimiento.comprobantePath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ComprobantePreview(
                movimiento: movimiento,
              ),
            ),
          const SizedBox(height: 24),
          _buildAcciones(context),
        ],
      ),
    );
  }

  Widget _buildAcciones(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'editar'),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Editar'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'eliminar'),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Eliminar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coral,
            side: const BorderSide(color: AppColors.coral),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComprobantePreview extends StatelessWidget {
  final Transaction movimiento;
  const _ComprobantePreview({required this.movimiento});
  @override
  Widget build(BuildContext context) {
    final path = movimiento.comprobantePath;
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    final isImage = (movimiento.comprobanteMimeType ?? '').toLowerCase().startsWith('image/');
    final file = File(path);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isImage ? Icons.image_rounded : Icons.description_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  movimiento.comprobanteNombre?.isNotEmpty == true ? movimiento.comprobanteNombre! : 'Comprobante',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: 220),
            )
          else
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.picture_as_pdf_rounded), title: const Text('Archivo adjunto'), subtitle: Text(movimiento.comprobanteNombre ?? 'Documento', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _DetalleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final int? maxLines;

  const _DetalleItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
