import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/categoria_personalizada.dart';
import '../../data/models/detalle_asignacion.dart';
import '../../data/models/plan_asignacion.dart';
import '../../data/providers/shared_providers.dart';
import '../../logic/asignaciones/asignacion_logic.dart';
import '../../logic/categorias/categoria_labels.dart';
import '../../shared/format/app_format.dart';
import '../../shared/format/miles_input_formatter.dart';
import '../../shared/mixins/guardando_mixin.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'asignacion_providers.dart';
import 'bolsillo_movimientos_screen.dart';

/// Reparto de un plan entre categorías, peso a peso.
///
/// La pantalla está centrada en una sola cifra: lo que todavía no tiene
/// destino. Se puede repartir de a pozo, sin guardar hasta que cierre, y ver
/// cómo va bajando el contador. Al guardar, los bolsillos se reemplazan en una
/// sola transacción y los movimientos de los bolsillos que desaparecen se
/// desvinculan para no dejar referencias colgando.
class PlanAsignacionScreen extends ConsumerStatefulWidget {
  const PlanAsignacionScreen({super.key, required this.planId});

  final int planId;

  @override
  ConsumerState<PlanAsignacionScreen> createState() =>
      _PlanAsignacionScreenState();
}

/// Marca para "crear categoría nueva" en la hoja de categorías.
const String _crearNueva = '__crear_nueva__';

/// Un bolsillo en edición. `gastado` se muestra pero no se puede tocar: es lo
/// que ya pasó, no una cifra que el usuario declare.
class _Bolsillo {
  _Bolsillo({
    required this.categoria,
    this.id,
    this.gastado = 0,
  }) : controller = TextEditingController();

  final int? id;
  final String categoria;
  final TextEditingController controller;
  final double gastado;

  factory _Bolsillo.de(DetalleAsignacion detalle, {double gastado = 0}) {
    return _Bolsillo(
      id: detalle.id,
      categoria: detalle.categoria,
      gastado: gastado,
    )..controller.text = AppFormat.montoParaEditar(detalle.montoAsignado);
  }

  factory _Bolsillo.nuevo(String categoria) => _Bolsillo(categoria: categoria);

  void dispose() => controller.dispose();
}

class _PlanAsignacionScreenState
    extends ConsumerState<PlanAsignacionScreen>
    with GuardandoMixin {
  final List<_Bolsillo> _bolsillos = [];
  bool _inicializado = false;

  @override
  void dispose() {
    for (final bolsillo in _bolsillos) {
      bolsillo.dispose();
    }
    super.dispose();
  }

  void _sincronizarDesdeProvider(ResumenPlan resumen) {
    if (_inicializado) return;
    _inicializado = true;
    for (final detalle in resumen.detalles) {
      _bolsillos.add(_Bolsillo.de(detalle.detalle, gastado: detalle.gastado));
    }
  }

  double get _totalAsignado => _bolsillos.fold<double>(
    0,
    (acc, b) => acc + (milesADouble(b.controller.text) ?? 0),
  );

  double _sinAsignar(double objetivo) => objetivo - _totalAsignado;

  @override
  Widget build(BuildContext context) {
    final resumen = ref.watch(resumenPlanProvider(widget.planId));

    if (resumen == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Plan'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
        ),
        body: Center(
          child: Text(
            'Este plan ya no existe.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    _sincronizarDesdeProvider(resumen);
    final plan = resumen.plan;
    final sinAsignar = _sinAsignar(plan.montoTotalObjetivo);
    final cuadrado = sinAsignar.abs() < 0.005;

    return protegerSalida(
      Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(plan.nombre),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _EncabezadoPlan(
              plan: plan,
              sinAsignar: sinAsignar,
              onActivarFondos: _activarFondos,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categorías',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (!plan.archivado)
                  TextButton.icon(
                    onPressed: _agregarBolsillo,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar'),
                  ),
              ],
            ),
            if (_bolsillos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  plan.archivado
                      ? 'Este plan está archivado.'
                      : 'Aún no repartiste nada. Agrega una categoría y '
                          'decí cuánto le toca de este plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              for (final bolsillo in _bolsillos)
                _FilaBolsillo(
                  bolsillo: bolsillo,
                  editable: !plan.archivado,
                  onCambiar: () => setState(() {}),
                  onEliminar: () => _eliminarBolsillo(bolsillo),
                  onAbrir: bolsillo.id == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BolsilloMovimientosScreen(
                              planId: widget.planId,
                              planDetalleId: bolsillo.id!,
                            ),
                          ),
                        ),
                ),
            const SizedBox(height: 12),
            if (!cuadrado && !plan.archivado)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sinAsignar > 0
                      ? AppColors.chipBackgroundCoral
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sinAsignar > 0
                      ? 'Te quedan ${AppFormat.moneda(sinAsignar)} sin '
                          'destinar a una categoría.'
                      : 'Destinaste ${AppFormat.moneda(sinAsignar.abs())} de '
                          'más: baja un monto para que cierre.',
                  style: TextStyle(
                    color: sinAsignar > 0
                        ? const Color(0xFF8C2F1C)
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: plan.archivado
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sin destinar',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              AppFormat.moneda(sinAsignar.abs()),
                              style: TextStyle(
                                color: cuadrado
                                    ? AppColors.primary
                                    : AppColors.coral,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: guardando ? null : _guardar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          cuadrado ? 'Listo' : 'Guardar',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _activarFondos() async {
    final plan = ref.read(resumenPlanProvider(widget.planId))!.plan;
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Activar fondos?',
      message:
          'El plan deja de ser proyectado: lo que asigne va a contar como '
          'saldo apartado de la cuenta. No se duplica ningún dinero, solo '
          'cambia el destino.',
      confirmLabel: 'Activar',
    );
    if (confirmado != true) return;

    try {
      await ref
          .read(planAsignacionRepositoryProvider)
          .update(plan.copyWith(esProyectado: false));
      ref.invalidate(planesAsignacionStreamProvider);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo activar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  Future<void> _guardar() async {
    final detalles = [
      for (final bolsillo in _bolsillos)
        DetalleAsignacion(
          id: bolsillo.id,
          planId: widget.planId,
          categoria: bolsillo.categoria,
          montoAsignado: milesADouble(bolsillo.controller.text) ?? 0,
        ),
    ];

    try {
      await ref
          .read(detalleAsignacionRepositoryProvider)
          .reemplazarDePlan(widget.planId, detalles);
      ref.invalidate(detallesAsignacionStreamProvider);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Reparto guardado',
          type: AppSnackbarType.success,
        );
      }
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

  void _eliminarBolsillo(_Bolsillo bolsillo) {
    setState(() {
      _bolsillos.remove(bolsillo);
      bolsillo.dispose();
    });
  }

  Future<void> _agregarBolsillo() async {
    final personalizadas =
        ref.read(categoriasPersonalizadasStreamProvider).asData?.value ??
        const <CategoriaPersonalizada>[];
    final todas = categoriasDeTipo('gasto', personalizadas);
    final usadas = _bolsillos.map((b) => b.categoria).toSet();
    final disponibles = todas
        .where((c) => !usadas.contains(c))
        .toList();

    final elegida = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HojaCategorias(disponibles: disponibles),
    );
    if (elegida == null || !mounted) return;

    if (elegida == _crearNueva) {
      final nombre = await _pedirNombreCategoria();
      if (nombre == null || !mounted) return;
      setState(() => _bolsillos.add(_Bolsillo.nuevo(nombre)));
      return;
    }

    setState(() => _bolsillos.add(_Bolsillo.nuevo(elegida)));
  }

  Future<String?> _pedirNombreCategoria() async {
    final controlador = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controlador.text.trim(),
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (resultado == null || resultado.isEmpty) return null;

    // Coincide con una existente: se usa esa sin crear una fila nueva.
    final existentes =
        ref.read(categoriasPersonalizadasStreamProvider).asData?.value ??
        const <CategoriaPersonalizada>[];
    final resuelta = categoriaCoincidenteDeNombre(
      nombre: resultado,
      tipo: 'gasto',
      existentes: existentes,
    );
    if (resuelta != null) return resuelta;

    try {
      await ref.read(categoriaPersonalizadaRepositoryProvider).insert(
        CategoriaPersonalizada(
          nombre: resultado,
          icono: 'category_rounded',
          tipo: 'gasto',
        ),
      );
      ref.invalidate(categoriasPersonalizadasStreamProvider);
    } catch (_) {
      // El nombre puede chocar con un duplicado; se usa igual y lo decide la
      // base al guardar.
    }
    return resultado;
  }
}

/// Encabezado del plan: objetivo, lo destinado y la acción de activar fondos
/// cuando es un plan proyectado.
class _EncabezadoPlan extends StatelessWidget {
  const _EncabezadoPlan({
    required this.plan,
    required this.sinAsignar,
    required this.onActivarFondos,
  });

  final PlanAsignacion plan;
  final double sinAsignar;
  final VoidCallback onActivarFondos;

  @override
  Widget build(BuildContext context) {
    final objetivo = plan.montoTotalObjetivo;
    final proyectado = plan.esProyectado;
    final archivado = plan.archivado;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dinero a repartir',
            style: TextStyle(
              color: AppColors.textOnPrimary.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppFormat.moneda(objetivo),
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CifraClara(
                etiqueta: 'Sin destinar',
                valor: AppFormat.moneda(sinAsignar.abs()),
              ),
              _CifraClara(
                etiqueta: sinAsignar > 0 ? 'Falta' : 'De más',
                valor: sinAsignar.abs() < 0.005 ? 'Nada' : 'Corrige',
              ),
            ],
          ),
          if (proyectado && !archivado) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan proyectado: este dinero todavía no está en la '
                    'cuenta, así que no descuenta de tu saldo.',
                    style: TextStyle(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.95),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: onActivarFondos,
                      child: const Text('Activar fondos'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CifraClara extends StatelessWidget {
  const _CifraClara({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            color: AppColors.textOnPrimary.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// Una categoría con su monto. El contador "sin destinar" se recalcula con cada
/// tecla, así que repartir se siente como contar billetes: se va viendo cuánto
/// sobra.
class _FilaBolsillo extends StatelessWidget {
  const _FilaBolsillo({
    required this.bolsillo,
    required this.editable,
    required this.onCambiar,
    required this.onEliminar,
    this.onAbrir,
  });

  final _Bolsillo bolsillo;
  final bool editable;
  final VoidCallback onCambiar;
  final VoidCallback onEliminar;

  /// Abre el historial de gastos del bolsillo. Es `null` para bolsillos que
  /// todavía no se guardaron (no tienen id), porque aún no tienen gastos
  /// vinculados que mostrar.
  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    final gastado = bolsillo.gastado;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onAbrir,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      iconoCategoria(bolsillo.categoria),
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelCategoria(bolsillo.categoria),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (gastado > 0)
                            Text(
                              'Gastado ${AppFormat.moneda(gastado)}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onAbrir != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: TextField(
              controller: bolsillo.controller,
              enabled: editable,
              onChanged: (_) => onCambiar(),
              keyboardType: TextInputType.number,
              inputFormatters: const [MilesInputFormatter()],
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: r'$ ',
                prefixStyle: const TextStyle(fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          if (editable)
            IconButton(
              onPressed: onEliminar,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Quitar categoría',
            ),
        ],
      ),
    );
  }
}

/// Hoja para elegir a qué categoría se le asigna dinero.
class _HojaCategorias extends StatelessWidget {
  const _HojaCategorias({required this.disponibles});

  final List<String> disponibles;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '¿A qué categoría le asignas?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          if (disponibles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Ya usaste todas las categorías de gasto.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: disponibles.length,
                itemBuilder: (_, index) {
                  final categoria = disponibles[index];
                  return ListTile(
                    leading: Icon(
                      iconoCategoria(categoria),
                      color: AppColors.primary,
                    ),
                    title: Text(labelCategoria(categoria)),
                    onTap: () => Navigator.pop(context, categoria),
                  );
                },
              ),
            ),
          ListTile(
            leading: Icon(Icons.add_rounded, color: AppColors.primary),
            title: const Text('Crear categoría nueva…'),
            onTap: () => Navigator.pop(context, _crearNueva),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
