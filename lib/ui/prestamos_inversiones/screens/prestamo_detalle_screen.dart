import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/loan.dart';
import '../../../logic/prestamos/prestamos_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../../movimientos/movimientos_providers.dart';
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
    final activos =
        ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
    String? nombreActivo;
    for (final activo in activos) {
      if (activo.id == actual.activoId) {
        nombreActivo = activo.nombre;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del préstamo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual, nombreActivo),
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
          _DatosPrestamo(
            prestamo: actual,
            estado: estado,
            nombreActivo: nombreActivo,
          ),
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
    final resultado = await _dialogoPago(context, ref, prestamo);
    if (resultado == null) return;

    final repo = ref.read(prestamoRepositoryProvider);
    try {
      final actualizado = await repo.registrarPago(
        prestamo.id!,
        resultado.monto,
        activoDestino: resultado.activoId,
      );
      if (actualizado == 0) {
        throw Exception('No se encontró el préstamo');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo registrar el pago',
          type: AppSnackbarType.error,
        );
      }
      return;
    }

    ref.invalidate(prestamosStreamProvider);
    ref.invalidate(movimientosStreamProvider);
    ref.invalidate(activosStreamProvider);
    if (context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Pago registrado. ${AppFormat.moneda(resultado.monto)} '
            'sumados al activo.',
        type: AppSnackbarType.success,
      );
    }
  }

  /// Diálogo del reembolso. Muestra a qué cuenta vuelve el dinero y deja
  /// cambiarla: normalmente es la misma de la que salió el préstamo, pero si esa
  /// cuenta se borró el usuario tiene que elegir otra (sin cuenta de destino el
  /// dinero aparecería de la nada).
  Future<({double monto, int activoId})?> _dialogoPago(
    BuildContext context,
    WidgetRef ref,
    Loan prestamo,
  ) async {
    final activos = ref.read(activosStreamProvider).asData?.value ??
        const <Asset>[];
    final restante = PrestamosLogic.montoRestante(prestamo);
    final montoController = TextEditingController(
      text: restante > 0 ? AppFormat.montoParaEditar(restante) : '',
    );

    final origenEliminado = activos.isNotEmpty &&
        (prestamo.activoId == null ||
            !activos.any((a) => a.id == prestamo.activoId));
    int? activoId = origenEliminado ? null : prestamo.activoId;

    final resultado = await showDialog<({double monto, int activoId})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: activoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta que recibe el pago *',
                    ),
                    items: [
                      for (final activo in activos)
                        DropdownMenuItem<int>(
                          value: activo.id,
                          child: Text(
                            '${activo.nombre} · '
                            '${AppFormat.moneda(activo.montoDisponible)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => activoId = value),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    origenEliminado
                        ? 'La cuenta de la que salió este préstamo ya no '
                            'existe, así que el pago debe entrar a una cuenta '
                            'de tu elección.'
                        : 'El pago se suma al saldo de esa cuenta.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Restante por cobrar: ${_formatearMonto(restante)}',
                    style: Theme.of(ctx).textTheme.bodySmall,
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
                    _avisar(ctx, 'Ingresa un monto válido');
                    return;
                  }
                  if (valor > restante) {
                    _avisar(
                      ctx,
                      'El pago no puede superar el monto restante de '
                      '${_formatearMonto(restante)}',
                    );
                    return;
                  }
                  if (activoId == null) {
                    _avisar(ctx, 'Elige la cuenta que recibe el pago');
                    return;
                  }
                  Navigator.pop(ctx, (monto: valor, activoId: activoId));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    montoController.dispose();
    return resultado;
  }

  void _avisar(BuildContext context, String mensaje) {
    AppSnackbar.show(context, message: mensaje, type: AppSnackbarType.error);
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
      if (guardado == true) {
        ref.invalidate(prestamosStreamProvider);
        ref.invalidate(movimientosStreamProvider);
        ref.invalidate(activosStreamProvider);
      }
    });
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Loan prestamo,
    String? nombreActivo,
  ) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Eliminar préstamo',
      message: '¿Eliminar el préstamo a ${prestamo.nombreBeneficiario}?\n\n'
          'Se borrarán sus movimientos y el dinero volverá a '
          '${nombreActivo ?? 'la cuenta de origen'}: '
          '${AppFormat.moneda(prestamo.montoPrestado)} '
          'que prestaste y ${AppFormat.moneda(prestamo.montoPagado)} '
          'que ya recuperaste.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmado != true) return;

    try {
      await ref.read(prestamoRepositoryProvider).delete(prestamo.id!);
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
    ref.invalidate(prestamosStreamProvider);
    ref.invalidate(movimientosStreamProvider);
    ref.invalidate(activosStreamProvider);
    if (context.mounted) Navigator.pop(context, true);
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
  final String? nombreActivo;

  const _DatosPrestamo({
    required this.prestamo,
    required this.estado,
    required this.nombreActivo,
  });

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final restante = PrestamosLogic.montoRestante(prestamo);

    final filas = <_FilaDesglose>[
      _FilaDesglose(
        label: 'Cuenta de origen',
        value: nombreActivo ?? 'Cuenta eliminada',
        valorGris: nombreActivo == null,
      ),
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