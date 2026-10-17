import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/asset.dart';
import '../../data/models/plan_asignacion.dart';
import '../../data/providers/shared_providers.dart';
import '../../shared/format/app_format.dart';
import '../../shared/format/miles_input_formatter.dart';
import '../../shared/mixins/guardando_mixin.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'asignacion_providers.dart';

/// Alta y edición de un plan de asignación AFCA.
///
/// Un plan reparte un monto entre categorías dentro de una cuenta. Sin meses:
/// dura lo que el usuario quiera, hasta que se archive. La distinción que
/// cambia el comportamiento es "con fondos" frente a "proyectado": un plan
/// proyectado planea dinero que todavía no existe y por eso no compromete saldo
/// hasta que se active.
class PlanFormScreen extends ConsumerStatefulWidget {
  const PlanFormScreen({super.key, this.plan});

  /// Plan existente cuando se está editando.
  final PlanAsignacion? plan;

  @override
  ConsumerState<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends ConsumerState<PlanFormScreen>
    with GuardandoMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController = TextEditingController(
    text: widget.plan?.nombre ?? '',
  );
  late final TextEditingController _montoController = TextEditingController(
    text: widget.plan == null
        ? ''
        : AppFormat.montoParaEditar(widget.plan!.montoTotalObjetivo),
  );

  late int? _activoId = widget.plan?.activoId;
  late bool _esProyectado = widget.plan?.esProyectado ?? false;

  bool get _editando => widget.plan != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() => ejecutarGuardado(_guardarReal);

  Future<void> _guardarReal() async {
    if (!_formKey.currentState!.validate()) return;

    final ahora = DateTime.now();
    final plan = PlanAsignacion(
      id: widget.plan?.id,
      activoId: _activoId,
      nombre: _nombreController.text.trim(),
      montoTotalObjetivo: milesADouble(_montoController.text) ?? 0,
      esProyectado: _esProyectado,
      archivado: widget.plan?.archivado ?? false,
      fechaCreacion: widget.plan?.fechaCreacion ?? ahora,
      fechaCierre: widget.plan?.fechaCierre,
    );

    try {
      final repo = ref.read(planAsignacionRepositoryProvider);
      if (plan.id == null) {
        await repo.insert(plan);
      } else {
        await repo.update(plan);
      }
      ref.invalidate(planesAsignacionStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  Future<void> _archivar() async {
    final plan = widget.plan!;
    if (plan.archivado) {
      // Reactivar: vuelve a contar para el saldo comprometido y acepta gastos.
      try {
        await ref
            .read(planAsignacionRepositoryProvider)
            .update(plan.copyWith(archivado: false, fechaCierreCleared: true));
        ref.invalidate(planesAsignacionStreamProvider);
        if (mounted) Navigator.pop(context, true);
      } catch (_) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No se pudo reactivar, intenta de nuevo',
            type: AppSnackbarType.error,
          );
        }
      }
      return;
    }

    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Archivar el plan?',
      message:
          'Deja de contar para el saldo asignado de la cuenta y sus bolsillos '
          'no aceptan gastos nuevos. Nada se borra: el historial se conserva.',
      confirmLabel: 'Archivar',
    );
    if (confirmado != true) return;

    try {
      await ref
          .read(planAsignacionRepositoryProvider)
          .update(plan.copyWith(archivado: true, fechaCierre: DateTime.now()));
      ref.invalidate(planesAsignacionStreamProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo archivar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activos =
        ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];
    final sinActivos = activos.isEmpty;

    return protegerSalida(
      Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_editando ? 'Editar plan' : 'Nuevo plan'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          actions: [
            if (_editando)
              IconButton(
                onPressed: _archivar,
                icon: Icon(
                  widget.plan!.archivado
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                tooltip: widget.plan!.archivado
                    ? 'Reactivar plan'
                    : 'Archivar plan',
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
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del plan',
                        helperText: 'Ej.: Quincena de marzo, Vacaciones…',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Escribe un nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    if (sinActivos)
                      Text(
                        'Primero crea una cuenta para poder asignarle dinero.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        key: const ValueKey('activo'),
                        initialValue: _activoId,
                        decoration: const InputDecoration(labelText: 'Cuenta'),
                        items: [
                          for (final activo in activos)
                            DropdownMenuItem(
                              value: activo.id,
                              child: Text(activo.nombre),
                            ),
                        ],
                        onChanged: _editando
                            ? null
                            : (v) => setState(() => _activoId = v),
                        validator: _editando
                            ? null
                            : (v) => v == null
                                ? 'Elige de qué cuenta sale el dinero'
                                : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _montoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [MilesInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Monto total a repartir',
                        prefixText: r'$ ',
                        helperText: 'Cuánto vas a repartir entre categorías',
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final monto = milesADouble(v);
                        if (monto == null || monto <= 0) {
                          return 'Escribe un monto mayor a 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  value: _esProyectado,
                  onChanged: _editando
                      ? null
                      : (v) => setState(() => _esProyectado = v),
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'Plan proyectado',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _esProyectado
                        ? 'Para planes previos a que entre el dinero. No '
                            'descuenta del saldo de la cuenta hasta que lo '
                            'actives.'
                        : 'El dinero ya está en la cuenta y queda apartado '
                            'para estas categorías.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: sinActivos || guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_editando ? 'Guardar cambios' : 'Crear plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
