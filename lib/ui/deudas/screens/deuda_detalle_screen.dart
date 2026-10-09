import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../data/models/debt.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/transaction.dart';
import '../../../logic/deudas/deudas_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../deudas_providers.dart';
import 'deuda_form_screen.dart';

class DeudaDetalleScreen extends ConsumerWidget {
  final Debt deuda;

  const DeudaDetalleScreen({super.key, required this.deuda});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudas =
        ref.watch(deudasStreamProvider).asData?.value ?? const [];
    Debt actual = deuda;
    for (final d in deudas) {
      if (d.id == deuda.id) {
        actual = d;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de deuda'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar deuda',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Encabezado(deuda: actual),
          const SizedBox(height: 16),
          _ProgresoDeuda(deuda: actual),
          const SizedBox(height: 16),
          _PlanPagos(deuda: actual),
          if (actual.observaciones != null) ...[
            const SizedBox(height: 16),
            _CardInfo(
              icon: Icons.sticky_note_2_rounded,
              titulo: 'Observaciones',
              child: Text(
                actual.observaciones!,
                style: Theme.of(context).textTheme.titleSmall!,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _registrarPago(context, ref, actual),
            icon: const Icon(Icons.payments_rounded),
            label: const Text('Registrar pago'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _editar(context, ref, actual),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar deuda'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarPago(
    BuildContext context,
    WidgetRef ref,
    Debt deuda,
  ) async {
    final resultado = await _dialogoPago(context, ref, deuda);
    if (resultado == null) return;

    final deudaRepo = ref.read(deudaRepositoryProvider);
    try {
      // Fuente única de verdad: primero se actualiza la deuda. Si falla, no
      // se crea ningún gasto ni se descuenta activo (sin cambios a medias).
      final actualizado = await deudaRepo.registrarPago(
        deuda.id!,
        resultado.monto,
      );
      if (actualizado == 0) {
        throw Exception('No se encontró la deuda para actualizarla');
      }

      if (resultado.registrarGasto) {
        final ahora = DateTime.now();
        // El saldo del activo lo descuenta el repositorio de movimientos, en
        // la misma transacción que guarda el gasto.
        await ref.read(movimientoRepositoryProvider).insert(
              Transaction(
                tipo: 'gasto',
                monto: resultado.monto,
                categoria: 'pagos',
                fecha: ahora,
                activoId: resultado.activoId,
                nota: 'Pago de ${deuda.nombreAcreedor}',
                fechaCreacion: ahora,
              ),
            );
      }
    } catch (_) {
      // Si algo falló después de actualizar la deuda, se restaura su
      // pendiente anterior para no dejar el registro a medias.
      await deudaRepo.update(
        deuda.copyWith(montoPendiente: deuda.montoPendiente),
      );
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo registrar el pago',
          type: AppSnackbarType.error,
        );
      }
      return;
    }

    ref.invalidate(deudasStreamProvider);
    if (context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Pago registrado',
        type: AppSnackbarType.success,
      );
    }
  }

  Future<_ResultadoPago?> _dialogoPago(
    BuildContext context,
    WidgetRef ref,
    Debt deuda,
  ) async {
    final montoController = TextEditingController(
      text: deuda.valorCuota != null
          ? AppFormat.montoParaEditar(deuda.valorCuota!)
          : '',
    );
    final conMovimiento = ValueNotifier<bool>(true);
    int? activoId;

    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctxInner, setStateInner) {
            final activos =
                ref.read(activosStreamProvider).asData?.value ?? const [];
            return AlertDialog(
              title: const Text('Registrar pago'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: montoController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [MilesInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Monto del pago',
                        hintText: 'Ej. 150.000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: conMovimiento,
                      builder: (_, valor, __) {
                        return SwitchListTile(
                          value: valor,
                          onChanged: (nuevo) {
                            conMovimiento.value = nuevo;
                            setStateInner(() {});
                          },
                          title: Text(
                            'Registrar como gasto',
                            style: Theme.of(context).textTheme.titleSmall!,
                          ),
                          subtitle: Text(
                            'Genera un movimiento tipo gasto.',
                            style: Theme.of(context).textTheme.bodySmall!,
                          ),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.primary,
                        );
                      },
                    ),
                    if (conMovimiento.value && activos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: activoId,
                        decoration:
                            const InputDecoration(labelText: 'Descontar de'),
                        hint: const Text('Sin activo'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Sin activo'),
                          ),
                          ...activos.map(
                            (asset) => DropdownMenuItem<int?>(
                              value: asset.id,
                              child: Text(
                                _formatearActivo(asset),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          activoId = value;
                          setStateInner(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      if (conMovimiento.value && activoId != null)
                        Text(
                          'Se descontará del saldo del activo seleccionado.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: AppColors.orange),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final valor = milesADouble(montoController.text);
                    if (valor == null || valor <= 0) {
                      AppSnackbar.show(
                        ctx,
                        message: 'Ingresa un monto válido',
                        type: AppSnackbarType.error,
                      );
                      return;
                    }
                    Navigator.pop(ctx, valor);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (monto == null) return null;

    montoController.dispose();
    conMovimiento.dispose();
    return _ResultadoPago(
      monto: monto,
      registrarGasto: conMovimiento.value,
      activoId: activoId,
    );
  }

  String _formatearActivo(Asset asset) {
    final symbol = asset.moneda == 'USD' ? r'US$' : r'$';
    return '${asset.nombre} (${AppFormat.moneda(asset.montoDisponible, symbol: symbol)})';
  }

  void _editar(BuildContext context, WidgetRef ref, Debt deuda) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DeudaFormScreen(deuda: deuda)))
        .then((guardado) {
      if (guardado == true) ref.invalidate(deudasStreamProvider);
    });
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Debt deuda,
  ) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Eliminar deuda',
      message: '¿Eliminar la deuda con ${deuda.nombreAcreedor}?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmado != true) return;

    try {
      await ref.read(deudaRepositoryProvider).delete(deuda.id!);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo eliminar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }
    ref.invalidate(deudasStreamProvider);
    if (context.mounted) Navigator.pop(context, true);
  }
}

class _Encabezado extends StatelessWidget {
  final Debt deuda;

  const _Encabezado({required this.deuda});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

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
              deuda.nombreAcreedor,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPrimary,
              ),
            ),
            if (deuda.plazo != null) ...[
              const SizedBox(height: 4),
              Text(
                deuda.plazo!,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                    ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              deuda.montoPendiente <= 0 ? 'Saldada' : 'Monto pendiente',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontSize: 13,
                color: AppColors.textOnPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currency(deuda.montoPendiente),
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgresoDeuda extends StatelessWidget {
  final Debt deuda;

  const _ProgresoDeuda({required this.deuda});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final saldada = deuda.montoPendiente <= 0;
    final progreso = DeudasLogic.progresoPago(deuda);
    final pagado = DeudasLogic.montoPagado(deuda);
    final inicial = DeudasLogic.montoInicialOf(deuda);

    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  saldada ? 'Deuda saldada' : 'Progreso de pago',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progreso * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: saldada ? AppColors.primary : AppColors.coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                color: saldada ? AppColors.primary : AppColors.coral,
                backgroundColor: AppColors.surfaceSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pagado: ${currency(pagado)} de ${currency(inicial)}',
              style: Theme.of(context).textTheme.bodySmall!,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPagos extends StatelessWidget {
  final Debt deuda;

  const _PlanPagos({required this.deuda});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    final cuotas = DeudasLogic.cuotasRestantesAprox(
      montoPendiente: deuda.montoPendiente,
      tasaInteresAnual: deuda.tasaInteres,
      valorCuota: deuda.valorCuota,
    );

    final filas = <_FilaDesglose>[];
    filas.add(_FilaDesglose(
      label: 'Monto inicial',
      value: currency(DeudasLogic.montoInicialOf(deuda)),
    ));
    filas.add(_FilaDesglose(
      label: 'Valor de la cuota',
      value: deuda.valorCuota != null
          ? currency(deuda.valorCuota!)
          : 'Sin cuota definida',
      valorGris: deuda.valorCuota == null,
    ));
    filas.add(_FilaDesglose(
      label: 'Tasa de interés',
      value: deuda.tasaInteres != null
          ? '${deuda.tasaInteres!.toStringAsFixed(1)}% anual'
          : 'No aplica',
      valorGris: deuda.tasaInteres == null,
    ));
    filas.add(_FilaDesglose(
      label: 'Cuotas restantes (aprox.)',
      value: cuotas == null
          ? 'No determinable'
          : '$cuotas ${cuotas == 1 ? 'cuota' : 'cuotas'}',
      destacado: cuotas != null,
      valorGris: cuotas == null,
    ));
    filas.add(_FilaDesglose(
      label: 'Próximo pago',
      value: deuda.fechaProximoPago == null
          ? 'Sin fecha'
          : DateFormat('dd MMM yyyy').format(deuda.fechaProximoPago!),
      valorGris: deuda.fechaProximoPago == null,
    ));

    if (deuda.montoPendiente <= 0) {
      filas.add(const _FilaDesglose(
        label: 'Estado',
        value: 'Saldada',
        destacado: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Plan de pagos',
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: filas
                  .map((fila) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: fila,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaDesglose extends StatelessWidget {
  final String label;
  final String value;
  final bool destacado;
  final bool valorGris;

  const _FilaDesglose({
    required this.label,
    required this.value,
    this.destacado = false,
    this.valorGris = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall!
              .copyWith(color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
              color: destacado
                  ? AppColors.primary
                  : (valorGris
                      ? AppColors.textSecondary
                      : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardInfo extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final Widget child;

  const _CardInfo({
    required this.icon,
    required this.titulo,
    required this.child,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultado del diálogo de pago: monto, si se registra como gasto y desde
/// qué activo (si aplica). La persistencia se hace en `_registrarPago`.
class _ResultadoPago {
  final double monto;
  final bool registrarGasto;
  final int? activoId;

  const _ResultadoPago({
    required this.monto,
    required this.registrarGasto,
    this.activoId,
  });
}