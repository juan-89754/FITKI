import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/investment.dart';
import '../../../logic/inversiones/inversiones_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../prestamos_inversiones_providers.dart';
import 'inversion_form_screen.dart';

class InversionDetalleScreen extends ConsumerWidget {
  final Investment inversion;

  const InversionDetalleScreen({super.key, required this.inversion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inversiones =
        ref.watch(inversionesStreamProvider).asData?.value ?? const <Investment>[];
    Investment actual = inversion;
    for (final i in inversiones) {
      if (i.id == inversion.id) {
        actual = i;
        break;
      }
    }

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
          _Encabezado(inversion: actual),
          const SizedBox(height: 16),
          _DatosInversion(inversion: actual, rendimiento: rendimiento),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _registrarGanancia(context, ref, actual),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Registrar ganancia obtenida'),
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

  Future<void> _registrarGanancia(
    BuildContext context,
    WidgetRef ref,
    Investment inversion,
  ) async {
    final ganancia = await _dialogoGanancia(context, inversion);
    if (ganancia == null) return;

    final repo = ref.read(inversionRepositoryProvider);
    try {
      final actualizado = await repo.registrarGanancia(inversion.id!, ganancia);
      if (actualizado == 0) {
        throw Exception('No se encontró la inversión');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar la ganancia'),
          ),
        );
      }
      return;
    }

    ref.invalidate(inversionesStreamProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ganancia registrada')),
      );
    }
  }

  Future<double?> _dialogoGanancia(
    BuildContext context,
    Investment inversion,
  ) async {
    final montoController = TextEditingController(
      text: inversion.gananciaObtenida != null
          ? AppFormat.montoParaEditar(inversion.gananciaObtenida!)
          : '',
    );

    final ganancia = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Registrar ganancia'),
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
                    labelText: 'Ganancia obtenida',
                    hintText: 'Ej. 250.000',
                    prefixText: r'$ ',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Deja en 0 si aún no has obtenido ganancia.',
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
                if (valor == null || valor < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un monto válido'),
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
    return ganancia;
  }

  void _editar(BuildContext context, WidgetRef ref, Investment inversion) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => InversionFormScreen(inversion: inversion),
      ),
    )
        .then((guardado) {
      if (guardado == true) ref.invalidate(inversionesStreamProvider);
    });
  }

  void _eliminar(BuildContext context, WidgetRef ref, Investment inversion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar inversión'),
        content: Text(
          '¿Eliminar la inversión en '
          '${InversionesLogic.labelTipo(inversion.tipo)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(inversionRepositoryProvider).delete(inversion.id!);
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
              ref.invalidate(inversionesStreamProvider);
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
  final Investment inversion;

  const _Encabezado({required this.inversion});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final tieneTasa = inversion.tasaRendimiento != null;

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
                if (tieneTasa)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackgroundOlive,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${inversion.tasaRendimiento!.toStringAsFixed(1)}% '
                      '${InversionesLogic.labelPeriodo(inversion.periodoTasa)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.oliveGreen,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd MMM yyyy').format(inversion.fecha),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Monto invertido',
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
          ],
        ),
      ),
    );
  }
}

class _DatosInversion extends StatelessWidget {
  final Investment inversion;
  final RendimientoInversion? rendimiento;

  const _DatosInversion({required this.inversion, required this.rendimiento});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    // Proyección a un período del mismo tipo que la tasa declarada.
    final proyectada = InversionesLogic.gananciaProyectada(
      inversion,
      periodoProyeccion: inversion.periodoTasa,
      numeroPeriodos: 1,
    );

    final filas = <_FilaDesglose>[
      _FilaDesglose(
        label: 'Ganancia proyectada '
            '(${InversionesLogic.labelPeriodoCorto(inversion.periodoTasa)})',
        value: tieneTasa()
            ? currency(proyectada)
            : 'Sin tasa definida',
        valorGris: !tieneTasa(),
      ),
    ];

    if (rendimiento != null) {
      filas.addAll([
        _FilaDesglose(
          label: 'Ganancia obtenida',
          value: currency(rendimiento!.gananciaObtenida),
          destacado: true,
          destacadoColor: rendimiento!.superaProyectada
              ? AppColors.primary
              : AppColors.coral,
        ),
        _FilaDesglose(
          label: 'Rendimiento real',
          value: '${rendimiento!.rendimientoPorcentaje.toStringAsFixed(2)}%',
          destacado: true,
        ),
        if (tieneTasa())
          _FilaDesglose(
            label: 'Vs. proyectada',
            value: '${rendimiento!.superaProyectada ? '+' : '-'}'
                '${currency(rendimiento!.diferencia.abs())}',
            destacado: true,
            destacadoColor: rendimiento!.superaProyectada
                ? AppColors.primary
                : AppColors.coral,
          ),
      ]);
    } else {
      filas.add(
        _FilaDesglose(
          label: 'Ganancia obtenida',
          value: inversion.gananciaObtenida == null
              ? 'Aún no registrada'
              : 'Sin datos suficientes',
          valorGris: true,
        ),
      );
    }

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

  bool tieneTasa() => inversion.tasaRendimiento != null;
}

class _FilaDesglose extends StatelessWidget {
  final String label;
  final String value;
  final bool destacado;
  final bool valorGris;
  final Color? destacadoColor;

  const _FilaDesglose({
    required this.label,
    required this.value,
    this.destacado = false,
    this.valorGris = false,
    this.destacadoColor,
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
                  ? (destacadoColor ?? AppColors.primary)
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