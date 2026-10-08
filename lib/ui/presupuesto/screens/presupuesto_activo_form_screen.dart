import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/abono_meta.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/gasto_fijo.dart';
import '../../../data/models/investment.dart';
import '../../../data/models/presupuesto_activo.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/activos/activos_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../metas/metas_providers.dart';
import '../../prestamos_inversiones/prestamos_inversiones_providers.dart';
import '../presupuesto_providers.dart';

/// Alta y edición del límite de gasto de una cuenta en el mes visible.
///
/// Si la cuenta tiene gastos fijos, se ofrecen como base del límite: la app
/// ya sabe cuánto va a salir de ahí cada mes.
class PresupuestoActivoFormScreen extends ConsumerStatefulWidget {
  const PresupuestoActivoFormScreen({
    super.key,
    required this.activo,
    this.presupuesto,
  });

  /// La cuenta a la que pertenece el límite. Siempre hace falta: el presupuesto
  /// está atado a un activo, no a una categoría.
  final Asset activo;
  final PresupuestoActivo? presupuesto;

  @override
  ConsumerState<PresupuestoActivoFormScreen> createState() =>
      _PresupuestoActivoFormScreenState();
}

class _PresupuestoActivoFormScreenState
    extends ConsumerState<PresupuestoActivoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoController = TextEditingController(
    text: widget.presupuesto == null
        ? ''
        : AppFormat.montoParaEditar(widget.presupuesto!.montoLimite),
  );

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  /// Lo que ya gastaron los gastos fijos de esta cuenta en el mes: el mejor
  /// punto de partida para un límite realista.
  double get _sugerenciaFijos {
    final periodo = ref.read(periodoVisibleProvider);
    final fijos =
        ref.read(gastosFijosStreamProvider).asData?.value ?? const <GastoFijo>[];
    return fijos
        .where(
          (f) => f.activoId == widget.activo.id && f.aplicaEn(periodo.mes, periodo.anio),
        )
        .fold<double>(0, (acc, f) => acc + f.montoEstimado);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = milesADouble(_montoController.text) ?? 0;
    final periodo = ref.read(periodoVisibleProvider);
    final repo = ref.read(presupuestoActivoRepositoryProvider);
    final ahora = DateTime.now();

    try {
      final existente = await repo.getByActivoYMes(
        widget.activo.id!,
        periodo.mes,
        periodo.anio,
      );
      final presupuesto = PresupuestoActivo(
        id: existente?.id ?? widget.presupuesto?.id,
        activoId: widget.activo.id!,
        mes: periodo.mes,
        anio: periodo.anio,
        montoLimite: monto,
        fechaCreacion: existente?.fechaCreacion ?? ahora,
      );

      if (presupuesto.id == null) {
        await repo.insert(presupuesto);
      } else {
        await repo.update(presupuesto);
      }
      ref.invalidate(presupuestosActivosStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar, intenta de nuevo')),
        );
      }
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar el presupuesto?'),
        content: const Text(
          'Se borra el límite de este mes. Los gastos ya registrados y sus '
          'movimientos no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await ref
          .read(presupuestoActivoRepositoryProvider)
          .delete(widget.presupuesto!.id!);
      ref.invalidate(presupuestosActivosStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar, intenta de nuevo')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodo = ref.watch(periodoVisibleProvider);
    final activos = ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
    final activosVisibles = activos.where((a) => a.id == widget.activo.id);
    final registros = ref.watch(registrosDeMetasProvider).asData?.value ?? const <AbonoMeta>[];
    final inversiones =
        ref.watch(inversionesStreamProvider).asData?.value ?? const <Investment>[];
    final saldoTotal = widget.activo.montoDisponible;
    final reservado = ActivosLogic.saldoReservadoEn(widget.activo.id, registros);
    final reservadoInversiones =
        ActivosLogic.saldoReservadoInversionesEn(widget.activo.id, inversiones);
    final saldoDisponible = ActivosLogic.saldoDisponible(
      saldoTotal,
      reservado,
      reservadoInversiones: reservadoInversiones,
    );
    final sugerencia = _sugerenciaFijos;
    final editando = widget.presupuesto != null;

    if (activosVisibles.isEmpty) {
      // El activo se borró mientras el formulario estaba abierto.
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Presupuesto')),
        body: const Center(child: Text('La cuenta ya no existe')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Presupuesto de ${widget.activo.nombre}'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          if (editando)
            IconButton(
              onPressed: _eliminar,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Quitar presupuesto',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodo.etiqueta,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _montoController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [MilesInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Límite de gasto del mes',
                      prefixText: r'$ ',
                      helperText: 'Cuánto quieres gastar de esta cuenta',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      final monto = milesADouble(v);
                      if (monto == null || monto <= 0) {
                        return 'Escribe un monto mayor a 0';
                      }
                      // El límite se compara contra el Saldo Disponible, no
                      // contra el total: un presupuesto que exceda lo que no
                      // está en metas promete algo que no se puede cumplir.
                      if (monto > saldoDisponible) {
                        return 'Esta cuenta solo tiene '
                            '${AppFormat.moneda(saldoDisponible)} disponibles.';
                      }
                      return null;
                    },
                  ),
                  if (reservado > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintPale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'De ${AppFormat.moneda(saldoTotal)} tienes '
                              '${AppFormat.moneda(reservado)} reservados en '
                              'metas, así que puedes gastar '
                              '${AppFormat.moneda(saldoDisponible)}.',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (sugerencia > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintPale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tus gastos fijos de esta cuenta suman '
                              '${AppFormat.moneda(sugerencia)} al mes',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _montoController.text =
                                AppFormat.montoParaEditar(sugerencia),
                            child: const Text('Usar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No tienes que registrar nada aquí dentro. La app compara este '
                'límite con los gastos que vas anotando en Movimientos, y con '
                'los pagos de tus gastos fijos.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(editando ? 'Guardar cambios' : 'Crear presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}
