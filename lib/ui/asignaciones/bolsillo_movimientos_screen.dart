import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/transaction.dart';
import '../../logic/asignaciones/asignacion_logic.dart';
import '../../logic/categorias/categoria_labels.dart';
import '../../shared/format/app_format.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/empty_state.dart';
import 'asignacion_providers.dart';

/// Drill-down de un bolsillo: en qué se fue el dinero asignado a una categoría
/// de un plan.
///
/// El "gastado" de un bolsillo no es un contador guardado, sino la suma de los
/// movimientos vinculados a él. Esta pantalla los lista para poder auditar ese
/// número: ver qué gastos lo componen y de qué fecha son.
class BolsilloMovimientosScreen extends ConsumerWidget {
  const BolsilloMovimientosScreen({
    super.key,
    required this.planId,
    required this.planDetalleId,
  });

  final int planId;
  final int planDetalleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenPlanProvider(planId));
    final movimientos = ref.watch(
      movimientosDeBolsilloProvider(planDetalleId),
    );

    ResumenDetalle? detalle;
    if (resumen != null) {
      for (final candidato in resumen.detalles) {
        if (candidato.detalle.id == planDetalleId) {
          detalle = candidato;
          break;
        }
      }
    }
    final categoria = detalle?.categoria ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(labelCategoria(categoria)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: movimientos.isEmpty
          ? EmptyState(
              icono: iconoCategoria(categoria),
              titulo: 'Sin gastos en este bolsillo',
              descripcion: 'Aquí verás los gastos que se imputen a esta '
                  'categoría del plan, con su fecha y monto.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (detalle != null) _EncabezadoBolsillo(detalle: detalle),
                const SizedBox(height: 16),
                for (final movimiento in movimientos)
                  _FilaMovimiento(movimiento: movimiento),
              ],
            ),
    );
  }
}

/// Resumen del bolsillo: lo gastado contra lo asignado, con cuánto queda o
/// cuánto se pasó.
class _EncabezadoBolsillo extends StatelessWidget {
  const _EncabezadoBolsillo({required this.detalle});

  final ResumenDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final color = detalle.superado ? AppColors.coral : AppColors.primary;
    final progreso = (detalle.porcentaje / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastado',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormat.moneda(detalle.gastado),
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'de ${AppFormat.moneda(detalle.asignado)} asignado',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 8,
              backgroundColor: AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detalle.superado
                ? 'Te pasaste ${AppFormat.moneda(detalle.excedido)} de lo '
                    'asignado.'
                : 'Te quedan ${AppFormat.moneda(detalle.restante)} '
                    'disponibles.',
            style: TextStyle(
              color: detalle.superado
                  ? AppColors.coral
                  : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un gasto imputado al bolsillo: su nota (o su categoría si no tiene) y su
/// fecha, con el monto a la derecha.
class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento});

  final Transaction movimiento;

  @override
  Widget build(BuildContext context) {
    final nota = movimiento.nota?.trim();
    final titulo = (nota != null && nota.isNotEmpty)
        ? nota
        : labelCategoria(movimiento.categoria);
    final fecha = DateFormat('dd MMM yyyy').format(movimiento.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fecha,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '-${AppFormat.moneda(movimiento.monto)}',
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
