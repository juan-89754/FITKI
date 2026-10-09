import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/asset.dart';
import '../../../data/models/investment.dart';
import '../../../data/models/inversion_movimiento.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../data/repositories/inversion_repository.dart';
import '../../../logic/inversiones/inversiones_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../prestamos_inversiones_providers.dart';
import 'inversion_form_screen.dart';

class InversionDetalleScreen extends ConsumerWidget {
  final Investment inversion;

  const InversionDetalleScreen({super.key, required this.inversion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inversiones =
        ref.watch(inversionesStreamProvider).asData?.value ??
            const <Investment>[];
    Investment actual = inversion;
    for (final i in inversiones) {
      if (i.id == inversion.id) {
        actual = i;
        break;
      }
    }

    final activos = ref.watch(activosStreamProvider).asData?.value ??
        const <Asset>[];
    Asset? activo;
    for (final a in activos) {
      if (a.id == actual.activoId) {
        activo = a;
        break;
      }
    }

    final movimientos = ref
            .watch(movimientosDeInversionProvider(actual.id!))
            .asData
            ?.value ??
        const <InversionMovimiento>[];

    final rendimiento = InversionesLogic.rendimientoReal(
      actual,
      periodoProyeccion: actual.periodoTasa,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de inversión'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar inversión',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Encabezado(inversion: actual, activo: activo),
          const SizedBox(height: 16),
          _Resumen(actual: actual, rendimiento: rendimiento),
          if (actual.notas != null) ...[
            const SizedBox(height: 16),
            _CardInfo(
              icon: Icons.sticky_note_2_rounded,
              titulo: 'Notas',
              child: Text(
                actual.notas!,
                style: Theme.of(context).textTheme.titleSmall!,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (actual.estaActiva) ...[
            Text(
              'Movimientos de la inversión',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _AccionesInversion(inversion: actual),
            const SizedBox(height: 16),
          ],
          _Historial(movimientos: movimientos),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _editar(context, ref, actual),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar inversión'),
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

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Investment inversion,
  ) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InversionFormScreen(inversion: inversion),
      ),
    );
    if (guardado == true) ref.invalidate(inversionesStreamProvider);
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Investment inversion,
  ) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Eliminar inversión',
      message: '¿Eliminar la inversión en '
          '${InversionesLogic.labelTipo(inversion.tipo)}? '
          'El capital reservado vuelve a estar disponible.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmado != true) return;

    try {
      await ref.read(inversionRepositoryProvider).delete(inversion.id!);
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
    ref.invalidate(inversionesStreamProvider);
    if (context.mounted) Navigator.pop(context, true);
  }
}

class _Encabezado extends StatelessWidget {
  final Investment inversion;
  final Asset? activo;

  const _Encabezado({required this.inversion, required this.activo});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final tieneTasa = inversion.tasaRendimiento != null;
    final activa = inversion.estaActiva;

    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    InversionesLogic.labelTipo(inversion.tipo),
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnPrimary,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activa
                        ? AppColors.chipBackgroundOlive
                        : AppColors.chipBackgroundCoral,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activa ? 'Activa' : 'Finalizada',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              activa ? AppColors.oliveGreen : AppColors.coral,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd MMM yyyy').format(inversion.fecha),
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Capital reservado',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              currency(inversion.montoInvertido),
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
            ),
            if (activo != null && activo!.nombre.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      activo!.nombre,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color:
                                AppColors.textOnPrimary.withValues(alpha: 0.85),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (tieneTasa) ...[
              const SizedBox(height: 8),
              Text(
                'Tasa: ${inversion.tasaRendimiento!.toStringAsFixed(1)}% '
                '${InversionesLogic.labelPeriodo(inversion.periodoTasa)}',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
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

class _Resumen extends StatelessWidget {
  final Investment actual;
  final RendimientoInversion? rendimiento;

  const _Resumen({required this.actual, required this.rendimiento});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final tieneTasa = actual.tasaRendimiento != null;
    final proyectada = InversionesLogic.gananciaProyectada(
      actual,
      periodoProyeccion: actual.periodoTasa,
      numeroPeriodos: 1,
    );
    final resultado = actual.gananciaObtenida ?? 0;
    final positivo = resultado >= 0;

    final filas = <_FilaDesglose>[
      if (tieneTasa)
        _FilaDesglose(
          label: 'Ganancia proyectada '
              '(${InversionesLogic.labelPeriodoCorto(actual.periodoTasa)})',
          value: currency(proyectada),
        ),
      _FilaDesglose(
        label: 'Resultado registrado',
        value: currency(resultado),
        destacado: true,
        destacadoColor: positivo ? AppColors.primary : AppColors.coral,
      ),
      if (rendimiento != null)
        _FilaDesglose(
          label: 'Rendimiento real',
          value: '${rendimiento!.rendimientoPorcentaje.toStringAsFixed(2)}%',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Rendimiento',
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
              children: [
                for (final fila in filas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: fila,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccionesInversion extends ConsumerWidget {
  final Investment inversion;

  const _AccionesInversion({required this.inversion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activoId = inversion.activoId;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Accion(
          icon: Icons.add_rounded,
          label: 'Aportar',
          onTap: activoId == null
              ? null
              : () => _pedirMontoYGuardar(
                    context,
                    ref,
                    tipo: InversionMovimiento.tipoAporte,
                  ),
        ),
        _Accion(
          icon: Icons.remove_rounded,
          label: 'Retirar',
          onTap: activoId == null
              ? null
              : () => _pedirMontoYGuardar(
                    context,
                    ref,
                    tipo: InversionMovimiento.tipoRetiro,
                  ),
        ),
        _Accion(
          icon: Icons.trending_up_rounded,
          label: 'Ganancia',
          onTap: () => _pedirMontoYGuardar(
            context,
            ref,
            tipo: InversionMovimiento.tipoGanancia,
          ),
        ),
        _Accion(
          icon: Icons.trending_down_rounded,
          label: 'Pérdida',
          onTap: () => _pedirMontoYGuardar(
            context,
            ref,
            tipo: InversionMovimiento.tipoPerdida,
          ),
        ),
        _Accion(
          icon: Icons.check_circle_outline_rounded,
          label: 'Finalizar',
          onTap: () => _finalizar(context, ref),
        ),
      ],
    );
  }

  Future<void> _pedirMontoYGuardar(
    BuildContext context,
    WidgetRef ref, {
    required String tipo,
  }) async {
    final esCapital = tipo == InversionMovimiento.tipoAporte ||
        tipo == InversionMovimiento.tipoRetiro;
    final titulo = switch (tipo) {
      InversionMovimiento.tipoAporte => 'Aportar capital',
      InversionMovimiento.tipoRetiro => 'Retirar capital',
      InversionMovimiento.tipoGanancia => 'Registrar ganancia',
      _ => 'Registrar pérdida',
    };

    final monto = await _pedirMonto(context, titulo: titulo);
    if (monto == null) return;

    final repo = ref.read(inversionRepositoryProvider);
    try {
      if (esCapital) {
        final activoId = inversion.activoId!;
        if (tipo == InversionMovimiento.tipoAporte) {
          await repo.registrarAporte(
            inversionId: inversion.id!,
            monto: monto,
            activoId: activoId,
            fecha: DateTime.now(),
          );
        } else {
          await repo.registrarRetiro(
            inversionId: inversion.id!,
            monto: monto,
            activoId: activoId,
            fecha: DateTime.now(),
          );
        }
      } else if (tipo == InversionMovimiento.tipoGanancia) {
        await repo.registrarGanancia(
          inversionId: inversion.id!,
          monto: monto,
        );
      } else {
        await repo.registrarPerdida(
          inversionId: inversion.id!,
          monto: monto,
        );
      }
    } on OperacionInversionInvalida catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: e.mensaje,
          type: AppSnackbarType.error,
        );
      }
      return;
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo registrar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }

    ref.invalidate(inversionesStreamProvider);
    ref.invalidate(movimientosDeInversionProvider(inversion.id!));
    if (context.mounted) {
      AppSnackbar.show(
        context,
        message: '$titulo registrado',
        type: AppSnackbarType.success,
      );
    }
  }

  Future<void> _finalizar(BuildContext context, WidgetRef ref) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Finalizar inversión',
      message: 'Se liberará el capital reservado y el resultado neto se '
          'registrará en el historial de movimientos: como ingreso si ganó, '
          'como gasto si perdió. Esta acción no se puede deshacer.',
      confirmLabel: 'Finalizar',
    );
    if (confirmado != true) return;

    try {
      await ref.read(inversionRepositoryProvider).finalizar(inversion.id!);
    } on OperacionInversionInvalida catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: e.mensaje,
          type: AppSnackbarType.error,
        );
      }
      return;
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo finalizar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }

    ref.invalidate(inversionesStreamProvider);
    ref.invalidate(movimientosDeInversionProvider(inversion.id!));
    if (context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Inversión finalizada',
        type: AppSnackbarType.success,
      );
    }
  }

  Future<double?> _pedirMonto(
    BuildContext context, {
    required String titulo,
  }) async {
    final controller = TextEditingController();
    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [MilesInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Monto',
            hintText: 'Ej. 250.000',
            prefixText: r'$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final valor = milesADouble(controller.text);
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
      ),
    );
    controller.dispose();
    return monto;
  }
}

class _Accion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Accion({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  final List<InversionMovimiento> movimientos;

  const _Historial({required this.movimientos});

  @override
  Widget build(BuildContext context) {
    if (movimientos.isEmpty) {
      return Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aún no hay movimientos registrados.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Historial',
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
          child: Column(
            children: [
              for (var i = 0; i < movimientos.length; i++) ...[
                _FilaMovimiento(movimiento: movimientos[i]),
                if (i < movimientos.length - 1)
                  Divider(
                    height: 1,
                    color: AppColors.borderSubtle.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  final InversionMovimiento movimiento;

  const _FilaMovimiento({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final (icono, label, color) = switch (movimiento.tipo) {
      InversionMovimiento.tipoAporte => (
          Icons.add_rounded,
          'Aporte',
          AppColors.primary,
        ),
      InversionMovimiento.tipoRetiro => (
          Icons.remove_rounded,
          'Retiro',
          AppColors.textSecondary,
        ),
      InversionMovimiento.tipoGanancia => (
          Icons.trending_up_rounded,
          'Ganancia',
          AppColors.primary,
        ),
      _ => (
          Icons.trending_down_rounded,
          'Pérdida',
          AppColors.coral,
        ),
    };

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icono, size: 18, color: color),
      ),
      title: Text(label),
      subtitle: Text(
        DateFormat('dd MMM yyyy').format(movimiento.fecha) +
            (movimiento.nota != null && movimiento.nota!.isNotEmpty
                ? ' · ${movimiento.nota}'
                : ''),
      ),
      trailing: Text(
        AppFormat.moneda(movimiento.monto),
        style: Theme.of(context)
            .textTheme
            .titleSmall!
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FilaDesglose extends StatelessWidget {
  final String label;
  final String value;
  final bool destacado;
  final Color? destacadoColor;

  const _FilaDesglose({
    required this.label,
    required this.value,
    this.destacado = false,
    this.destacadoColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: destacado
                    ? (destacadoColor ?? AppColors.textPrimary)
                    : AppColors.textPrimary,
                fontWeight:
                    destacado ? FontWeight.w700 : FontWeight.w500,
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