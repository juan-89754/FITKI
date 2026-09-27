import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/loan.dart';
import '../../../logic/prestamos/prestamos_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../prestamos_inversiones_providers.dart';
import 'prestamo_form_screen.dart';

class PrestamoDetalleScreen extends ConsumerWidget {
  final Loan prestamo;

  const PrestamoDetalleScreen({super.key, required this.prestamo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prestamos =
        ref.watch(prestamosStreamProvider).asData?.value ?? const <Loan>[];
    Loan actual = prestamo;
    for (final p in prestamos) {
      if (p.id == prestamo.id) {
        actual = p;
        break;
      }
    }

    final estado = PrestamosLogic.estadoDe(actual);
    final pagado = estado == 'pagado_total';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del préstamo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar préstamo',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Encabezado(prestamo: actual, estado: estado),
          const SizedBox(height: 16),
          _DatosPrestamo(prestamo: actual, estado: estado),
          if (actual.condiciones != null) ...[
            const SizedBox(height: 16),
            _CardInfo(
              icon: Icons.description_rounded,
              titulo: 'Condiciones',
              child: Text(
                actual.condiciones!,
                style: Theme.of(context).textTheme.titleSmall!,
              ),
            ),
          ],
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
          if (!pagado)
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
          if (!pagado) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _editar(context, ref, actual),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar préstamo'),
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
    Loan prestamo,
  ) async {
    final monto = await _dialogoPago(context, prestamo);
    if (monto == null) return;

    final repo = ref.read(prestamoRepositoryProvider);
    try {
      final actualizado = await repo.registrarPago(prestamo.id!, monto);
      if (actualizado == 0) {
        throw Exception('No se encontró el préstamo');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar el pago'),
          ),
        );
      }
      return;
    }

    ref.invalidate(prestamosStreamProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado')),
      );
    }
  }

  Future<double?> _dialogoPago(BuildContext context, Loan prestamo) async {
    final restante = PrestamosLogic.montoRestante(prestamo);
    final montoController = TextEditingController(
      text: restante > 0 ? AppFormat.montoParaEditar(restante) : '',
    );

    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) {
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
                    labelText: 'Monto recibido',
                    hintText: 'Ej. 300.000',
                    prefixText: r'$ ',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Restante por cobrar: ${_formatearMonto(restante)}',
                  style: Theme.of(context).textTheme.bodySmall!,
                ),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un monto válido'),
                    ),
                  );
                  return;
                }
                if (valor > restante) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'El pago no puede superar el monto restante de '
                        '${_formatearMonto(restante)}',
                      ),
                    ),
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

    montoController.dispose();
    return monto;
  }

  String _formatearMonto(double valor) {
    return AppFormat.moneda(valor);
  }

  void _editar(BuildContext context, WidgetRef ref, Loan prestamo) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => PrestamoFormScreen(prestamo: prestamo),
      ),
    )
        .then((guardado) {
      if (guardado == true) ref.invalidate(prestamosStreamProvider);
    });
  }

  void _eliminar(BuildContext context, WidgetRef ref, Loan prestamo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar préstamo'),
        content: Text(
          '¿Eliminar el préstamo a ${prestamo.nombreBeneficiario}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(prestamoRepositoryProvider).delete(prestamo.id!);
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
              ref.invalidate(prestamosStreamProvider);
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
  final Loan prestamo;
  final String estado;

  const _Encabezado({required this.prestamo, required this.estado});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final restante = PrestamosLogic.montoRestante(prestamo);

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
              prestamo.nombreBeneficiario,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              PrestamosLogic.labelEstado(estado),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              estado == 'pagado_total' ? 'Préstamo liquidado' : 'Monto prestado',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontSize: 13,
                color: AppColors.textOnPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currency(prestamo.montoPrestado),
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textOnPrimary,
              ),
            ),
            if (estado != 'pagado_total') ...[
              const SizedBox(height: 10),
              Text(
                'Recibido ${currency(prestamo.montoPagado)} · '
                'Por cobrar ${currency(restante)}',
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

class _DatosPrestamo extends StatelessWidget {
  final Loan prestamo;
  final String estado;

  const _DatosPrestamo({required this.prestamo, required this.estado});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final restante = PrestamosLogic.montoRestante(prestamo);

    final filas = <_FilaDesglose>[
      _FilaDesglose(
        label: 'Fecha del préstamo',
        value: DateFormat('dd MMM yyyy').format(prestamo.fechaPrestamo),
      ),
      _FilaDesglose(
        label: 'Fecha esperada de pago',
        value: DateFormat('dd MMM yyyy').format(prestamo.fechaPagoEsperada),
      ),
      _FilaDesglose(
        label: 'Recuperado',
        value: currency(prestamo.montoPagado),
      ),
      _FilaDesglose(
        label: 'Por cobrar',
        value: currency(restante),
      ),
      _FilaDesglose(
        label: 'Estado',
        value: PrestamosLogic.labelEstado(estado),
        destacado: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Datos del préstamo',
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

  const _FilaDesglose({
    required this.label,
    required this.value,
    this.destacado = false,
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
              color: destacado ? AppColors.primary : AppColors.textPrimary,
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
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
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