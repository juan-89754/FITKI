import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/asset.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/gastos/gastos_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/forms/activo_obligatorio.dart';
import '../../../shared/theme/app_colors.dart';
import '../../movimientos/movimientos_providers.dart';
import '../presupuesto_providers.dart';

/// Hoja de pago de los gastos fijos del mes.
///
/// De precio fijo: un toque y se registra con el monto ya escrito.
/// De precio variable: el monto llega precargado con el promedio de los últimos
/// pagos y solo hay que corregirlo si la boleta salió otro valor.
///
/// Ningún pago se registra sin activo: si a la plantilla se le borró la cuenta
/// que la respaldaba, se pregunta cuál usar antes de confirmar.
Future<void> mostrarHojaDePagos(
  BuildContext context,
  WidgetRef ref,
  List<PendientePago> pendientes,
) async {
  if (pendientes.isEmpty) return;

  final activos = ref.read(activosStreamProvider).asData?.value ?? const <Asset>[];
  if (activos.isEmpty) {
    await mostrarAviso(
      context,
      'Necesitas un activo',
      'Crea primero una cuenta o activo para poder registrar el pago. '
      'Todo gasto debe salir de una cuenta para que el presupuesto sume bien.',
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _HojaDePagos(pendientes: pendientes, activos: activos),
  );
}

class _HojaDePagos extends ConsumerStatefulWidget {
  const _HojaDePagos({required this.pendientes, required this.activos});

  final List<PendientePago> pendientes;
  final List<Asset> activos;

  @override
  ConsumerState<_HojaDePagos> createState() => _HojaDePagosState();
}

class _HojaDePagosState extends ConsumerState<_HojaDePagos> {
  final Map<int, TextEditingController> _montos = {};
  final Map<int, int?> _activosElegidos = {};
  final Set<int> _seleccionados = {};
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    final activos =
        ref.read(activosStreamProvider).asData?.value ?? const <Asset>[];
    // Se arman aquí y no en la declaración: un inicializador de campo no
    // puede leer `widget`.
    for (final pendiente in widget.pendientes) {
      final id = pendiente.pago.id!;
      _montos[id] = TextEditingController(
        text: AppFormat.montoParaEditar(pendiente.montoSugerido),
      );
      // La plantilla ya guarda su cuenta; si le falta y solo hay una, se usa
      // esa, que es lo mismo que hace el formulario de movimientos.
      final dePlantilla = pendiente.plantilla.activoId;
      _activosElegidos[id] = dePlantilla ??
          (activos.length == 1 ? activos.first.id : null);
    }
  }

  @override
  void dispose() {
    for (final controller in _montos.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _totalSeleccionado {
    var total = 0.0;
    for (final p in widget.pendientes) {
      if (!_seleccionados.contains(p.pago.id)) continue;
      total += milesADouble(_montos[p.pago.id]?.text) ?? 0;
    }
    return total;
  }

  /// Los de precio fijo que ya tienen activo: se pagan de un solo toque sin
  /// que el usuario escriba nada.
  Iterable<PendientePago> get _faciles => widget.pendientes
      .where((p) => !p.plantilla.montoVariable && !p.requiereActivo);

  Future<void> _pagarSeleccionados() async {
    if (_seleccionados.isEmpty || _procesando) return;
    setState(() => _procesando = true);

    final repoPagos = ref.read(pagoGastoFijoRepositoryProvider);
    final errores = <String>[];

    for (final pendiente in widget.pendientes) {
      final id = pendiente.pago.id!;
      if (!_seleccionados.contains(id)) continue;

      final monto = milesADouble(_montos[id]?.text) ?? 0;
      if (monto <= 0) {
        errores.add('${pendiente.plantilla.nombre}: el monto no es válido');
        continue;
      }
      final activoId = _activosElegidos[id];
      if (activoId == null) {
        errores.add('${pendiente.plantilla.nombre}: falta elegir la cuenta');
        continue;
      }

      try {
        await repoPagos.registrarPagoConMovimiento(
          pago: pendiente.pago,
          categoria: pendiente.plantilla.categoria,
          monto: monto,
          activoId: activoId,
          fechaPago: DateTime.now(),
          nota: pendiente.plantilla.nombre,
        );
      } catch (_) {
        errores.add('${pendiente.plantilla.nombre}: no se pudo registrar');
      }
    }

    ref.invalidate(pagosGastosFijosStreamProvider);
    ref.invalidate(pagosDelMesProvider);
    ref.invalidate(movimientosStreamProvider);
    ref.invalidate(activosStreamProvider);

    if (!mounted) return;
    setState(() => _procesando = false);

    if (errores.isEmpty) {
      // El messenger se toma antes de cerrar: después del pop este context
      // ya no está montado y mostrarlo revienta.
      final messenger = ScaffoldMessenger.of(context);
      final cuantos = _seleccionados.length;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('$cuantos pagos registrados')),
      );
    } else {
      await mostrarAviso(context, 'Faltaron algunos pagos', errores.join('\n'));
      setState(_seleccionados.clear);
    }
  }

  Future<void> _seleccionarActivo(PendientePago pendiente) async {
    final id = await resolverActivoDeGasto(
      context,
      activos: widget.activos,
      actual: _activosElegidos[pendiente.pago.id!],
    );
    if (id != null && mounted) {
      setState(() => _activosElegidos[pendiente.pago.id!] = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activosPorId = {for (final a in widget.activos) a.id: a};

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pagar gastos fijos',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      if (_faciles.isNotEmpty) {
                        for (final p in _faciles) {
                          _seleccionados.add(p.pago.id!);
                        }
                      }
                    }),
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    tooltip: 'Seleccionar los de precio fijo',
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final pendiente in widget.pendientes)
                    _FilaPago(
                      pendiente: pendiente,
                      controller: _montos[pendiente.pago.id]!,
                      seleccionado: _seleccionados.contains(pendiente.pago.id),
                      activo: activosPorId[_activosElegidos[pendiente.pago.id!]],
                      onToggle: () => setState(() {
                        final id = pendiente.pago.id!;
                        _seleccionados.contains(id)
                            ? _seleccionados.remove(id)
                            : _seleccionados.add(id);
                      }),
                      onMontoCambio: () => setState(() {}),
                      onElegirActivo: () => _seleccionarActivo(pendiente),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_seleccionados.length} de ${widget.pendientes.length}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        AppFormat.moneda(_totalSeleccionado),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _seleccionados.isEmpty || _procesando
                          ? null
                          : _pagarSeleccionados,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _procesando
                            ? 'Registrando...'
                            : 'Registrar pago y descontar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaPago extends StatelessWidget {
  const _FilaPago({
    required this.pendiente,
    required this.controller,
    required this.seleccionado,
    required this.activo,
    required this.onToggle,
    required this.onMontoCambio,
    required this.onElegirActivo,
  });

  final PendientePago pendiente;
  final TextEditingController controller;
  final bool seleccionado;
  final Asset? activo;
  final VoidCallback onToggle;
  final VoidCallback onMontoCambio;
  final VoidCallback onElegirActivo;

  @override
  Widget build(BuildContext context) {
    final plantilla = pendiente.plantilla;
    final vencido =
        !pendiente.fechaPago.isAfter(DateTime.now()) && !seleccionado;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: seleccionado
            ? AppColors.mintPale
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seleccionado ? AppColors.primary : AppColors.borderSubtle,
        ),
      ),
      child: CheckboxListTile(
        value: seleccionado,
        onChanged: (_) => onToggle(),
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Expanded(
              child: Text(
                plantilla.nombre,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (plantilla.montoVariable)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBackgroundOrange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Variable',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${labelCategoria(plantilla.categoria)} · '
              'vence ${pendiente.fechaPago.day}/${pendiente.fechaPago.month}'
              '${vencido ? ' · vencido' : ''}',
              style: TextStyle(
                color: vencido ? AppColors.coral : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [MilesInputFormatter()],
                    onChanged: (_) => onMontoCambio(),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: r'$ ',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (activo != null)
                  ActionChip(
                    avatar: const Icon(Icons.account_balance_rounded, size: 16),
                    label: Text(activo!.nombre),
                    onPressed: onElegirActivo,
                  )
                else
                  TextButton.icon(
                    onPressed: onElegirActivo,
                    icon: const Icon(Icons.error_outline_rounded, size: 18),
                    label: const Text('Elegir cuenta'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
