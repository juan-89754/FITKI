import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/abono_meta.dart';
import '../../../data/models/financial_goal.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../data/repositories/meta_repository.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/metas/metas_logic.dart';
import '../../activos/activos_providers.dart';
import '../metas_providers.dart';
import 'meta_form_screen.dart';

class MetaDetalleScreen extends ConsumerWidget {
  final FinancialGoal meta;

  const MetaDetalleScreen({super.key, required this.meta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metas = ref.watch(metasStreamProvider).asData?.value ?? const [];
    FinancialGoal? actual = meta;
    for (final m in metas) {
      if (m.id == meta.id) {
        actual = m;
        break;
      }
    }
    final registros =
        ref.watch(registrosDeMetaProvider(actual!.id!)).asData?.value ??
            const <AbonoMeta>[];

    // El saldo sale del historial de registros, no del campo acumulado, para
    // que la pantalla nunca pueda mostrar un avance descuadrado con los aportes
    // y retiros que el usuario ve más abajo.
    final calculo = MetasLogic.calcular(actual, registros: registros);
    final activos = ref.watch(activosConSaldoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de meta'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            onPressed: () => _eliminar(context, ref, actual!),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar meta',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Encabezado(calculo: calculo),
          const SizedBox(height: 16),
          _ExplicacionReserva(activo: _activoConReserva(registros, activos)),
          const SizedBox(height: 16),
          if (calculo.meta.comentarios != null) ...[
            _CardInfo(
              icon: Icons.sticky_note_2_rounded,
              titulo: 'Comentarios',
              child: Text(
                calculo.meta.comentarios!,
                style: Theme.of(context).textTheme.titleSmall!,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _DesgloseCalculo(calculo: calculo),
          const SizedBox(height: 24),
          _ListaRegistros(
            registros: registros,
            activos: activos,
            onQuitar: (registro) => _quitarRegistro(context, ref, registro),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _abrirRegistro(context, ref, esAporte: true),
            icon: const Icon(Icons.savings_rounded),
            label: const Text('Aportar a la meta'),
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
            onPressed: () => _abrirRegistro(context, ref, esAporte: false),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Retirar de la meta'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _editar(context, ref, actual!),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar meta'),
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

  /// Cuenta desde la que se aportó más dinero a esta meta, para poder nombrar en
  /// el resumen dónde está hoy el dinero apartado. `null` si la meta todavía no
  /// tiene aportes, o si la cuenta desde la que se apartó ya no existe.
  ActivoConSaldo? _activoConReserva(
    List<AbonoMeta> registros,
    List<ActivoConSaldo> activos,
  ) {
    final porCuenta = <int, double>{};
    for (final registro in registros) {
      final id = registro.activoId;
      if (id == null) continue;
      porCuenta[id] = (porCuenta[id] ?? 0) + registro.montoConSigno;
    }
    if (porCuenta.isEmpty) return null;

    int? mejorId;
    double mejorSaldo = 0;
    porCuenta.forEach((id, saldo) {
      if (saldo > mejorSaldo) {
        mejorSaldo = saldo;
        mejorId = id;
      }
    });

    for (final activo in activos) {
      if (activo.id == mejorId) return activo;
    }
    return null;
  }

  /// Abre el diálogo de aporte o de retiro y lo registra.
  ///
  /// El activo es obligatorio en los dos casos, pero por motivos distintos: en
  /// un aporte es de dónde sale el dinero, y en un retiro es a dónde vuelve.
  /// Por eso el mismo campo significa cosas distintas según el caso.
  ///
  /// La cuenta es obligatoria en el aporte porque el dinero no puede quedar
  /// reservado sin saber de dónde vino; en el retiro se limita a las cuentas
  /// que efectivamente tienen reservas de esta meta, porque devolverlo a otra
  /// cuenta haría desaparecer una reserva de donde sí se apartó.
  Future<void> _abrirRegistro(
    BuildContext context,
    WidgetRef ref, {
    required bool esAporte,
  }) async {
    final registros =
        ref.read(registrosDeMetaProvider(meta.id!)).asData?.value ??
            const <AbonoMeta>[];
    final activos = ref.read(activosConSaldoProvider);

    // En un aporte se puede usar cualquier cuenta con saldo libre; en un retiro
    // solo las que tienen dinero de esta meta reservado.
    final opciones = esAporte
        ? activos
        : activos
              .where(
                (a) => MetasLogic.reservadoEnActivo(registros, a.id) > 0,
              )
              .toList();

    if (opciones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              esAporte
                  ? 'No hay cuentas con saldo disponible para aportar'
                  : 'Esta meta no tiene dinero reservado en ninguna cuenta',
            ),
          ),
        );
      }
      return;
    }

    final datos = await _dialogoRegistro(
      context,
      esAporte: esAporte,
      opciones: opciones,
    );
    if (datos == null || !context.mounted) return;

    final repo = ref.read(metaRepositoryProvider);
    try {
      if (esAporte) {
        await repo.registrarAporte(
          metaId: meta.id!,
          monto: datos.monto,
          activoId: datos.activoId,
          fecha: datos.fecha,
          nota: datos.nota,
        );
      } else {
        await repo.registrarRetiro(
          metaId: meta.id!,
          monto: datos.monto,
          activoId: datos.activoId,
          fecha: datos.fecha,
          nota: datos.nota,
        );
      }
    } on OperacionMetaInvalida catch (e) {
      // El repositorio es la autoridad: si algo no cuadra, su mensaje explica
      // exactamente qué falta, y se muestra tal cual.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensaje)),
        );
      }
      return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              esAporte
                  ? 'No se pudo registrar el aporte'
                  : 'No se pudo registrar el retiro',
            ),
          ),
        );
      }
      return;
    }

    _refrescarTrasRegistro(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esAporte ? 'Aporte registrado' : 'Retiro registrado',
          ),
        ),
      );
    }
  }

  /// Quita un aporte o un retiro del historial. Se pide confirmación porque
  /// cambia el saldo de la meta y la disponibilidad de la cuenta.
  Future<void> _quitarRegistro(
    BuildContext context,
    WidgetRef ref,
    AbonoMeta registro,
  ) async {
    final esAporte = registro.esAporte;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esAporte ? 'Quitar aporte' : 'Quitar retiro'),
        content: Text(
          '¿Quitar el ${esAporte ? 'aporte' : 'retiro'} de '
          '${AppFormat.moneda(registro.monto)} del '
          '${DateFormat('dd MMM yyyy').format(registro.fecha)}?\n\n'
          'La meta deja de sumar ese monto en su avance y el dinero vuelve a '
          'estar disponible para gastar en la cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      final eliminados = await ref
          .read(metaRepositoryProvider)
          .eliminarRegistro(registro.id!);
      if (eliminados == 0) throw Exception('El registro ya no existe');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo quitar, intenta de nuevo')),
        );
      }
      return;
    }

    _refrescarTrasRegistro(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esAporte ? 'Aporte quitado' : 'Retiro quitado')),
      );
    }
  }

  /// Un aporte o retiro cambia el saldo derivado de la meta y el Saldo Disponible
  /// de las cuentas, así que ambos streams se invalidan juntos. Los movimientos
  /// **no** se tocan: un aporte no escribe ninguno, y ese es justamente el punto.
  void _refrescarTrasRegistro(WidgetRef ref) {
    ref.invalidate(metasStreamProvider);
    ref.invalidate(registrosDeMetaProvider(meta.id!));
    ref.invalidate(registrosDeMetasProvider);
    ref.invalidate(activosStreamProvider);
  }

  /// Diálogo de aporte o retiro: monto, cuenta, fecha y nota.
  ///
  /// La cuenta muestra siempre el número que limita la operación (disponible si
  /// es un aporte, reservado si es un retiro), para que el usuario vea por qué
  /// una cuenta no le deja separar más.
  Future<_DatosRegistro?> _dialogoRegistro(
    BuildContext context, {
    required bool esAporte,
    required List<ActivoConSaldo> opciones,
  }) async {
    final controller = TextEditingController();
    final notaController = TextEditingController();
    var activoId = opciones.first.id;
    DateTime fecha = DateTime.now();

    final resultado = await showDialog<_DatosRegistro>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(esAporte ? 'Aportar a la meta' : 'Retirar de la meta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [MilesInputFormatter()],
                  decoration: InputDecoration(
                    labelText: esAporte ? 'Monto a aportar' : 'Monto a retirar',
                    hintText: 'Ej. 200.000',
                    prefixText: r'$ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: activoId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: esAporte ? 'Cuenta de origen' : 'Cuenta de destino',
                  ),
                  items: opciones
                      .map(
                        (a) => DropdownMenuItem<int>(
                          value: a.id,
                          child: Text(
                            '${a.nombre} · '
                            '${esAporte ? 'disponible' : 'reservado'} '
                            '${AppFormat.moneda(a.saldoDisponible)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (valor) => setState(() => activoId = valor!),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final elegida = await showDatePicker(
                      context: ctx,
                      initialDate: fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (elegida != null) setState(() => fecha = elegida);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    'Fecha: ${DateFormat('dd MMM yyyy').format(fecha)}',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notaController,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Ej. Ahorro del mes',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  esAporte
                      ? 'El dinero no sale de la cuenta: queda reservado en esta '
                            'meta y deja de estar disponible para gastar.'
                      : 'El dinero vuelve a estar disponible para gastar en esa '
                            'cuenta.',
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
                final valor = milesADouble(controller.text);
                if (valor == null || valor <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Ingresa un monto válido')),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  _DatosRegistro(
                    monto: valor,
                    activoId: activoId,
                    fecha: fecha,
                    nota: notaController.text.trim().isEmpty
                        ? null
                        : notaController.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: Text(esAporte ? 'Aportar' : 'Retirar'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    notaController.dispose();
    return resultado;
  }

  void _editar(BuildContext context, WidgetRef ref, FinancialGoal meta) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MetaFormScreen(meta: meta)))
        .then((guardado) {
      if (guardado == true) ref.invalidate(metasStreamProvider);
    });
  }

void _eliminar(BuildContext context, WidgetRef ref, FinancialGoal meta) {
    final registros =
        ref.read(registrosDeMetaProvider(meta.id!)).asData?.value ??
            const <AbonoMeta>[];
    final saldo = MetasLogic.saldoDeMeta(registros);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text(
          registros.isEmpty
              ? '¿Eliminar "${meta.nombre}"?'
              : '¿Eliminar "${meta.nombre}"?\n\n'
                    'Esta meta tiene ${registros.length} '
                    '${registros.length == 1 ? 'registro' : 'registros'} y '
                    '${AppFormat.moneda(saldo)} apartados. Al eliminarla, esa '
                    'reserva desaparece y el dinero vuelve a estar disponible '
                    'para gastar. El dinero nunca salió de las cuentas, así que '
                    'no se devuelve nada: simplemente deja de estar apartado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(metaRepositoryProvider).delete(meta.id!);
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
              _refrescarTrasRegistro(ref);
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

/// Lo que el usuario eligió en el diálogo de aporte o retiro.
class _DatosRegistro {
  final double monto;
  final int activoId;
  final DateTime fecha;
  final String? nota;

  const _DatosRegistro({
    required this.monto,
    required this.activoId,
    required this.fecha,
    this.nota,
  });
}

/// Aclara qué significa aportar, porque es la parte de las metas que más
/// confunde: el dinero no se gasta, solo deja de estar disponible.
class _ExplicacionReserva extends StatelessWidget {
  final ActivoConSaldo? activo;

  const _ExplicacionReserva({required this.activo});

  @override
  Widget build(BuildContext context) {
    final enCuenta = activo == null
        ? null
        : '${activo!.nombre} (${AppFormat.moneda(activo!.reservado)})';

    return _CardInfo(
      icon: Icons.lock_outline_rounded,
      titulo: 'Cómo funciona',
      child: Text(
        enCuenta == null
            ? 'Aportar a una meta no mueve dinero de la cuenta: lo deja '
                  'reservado para ese objetivo. El dinero sigue siendo tuyo y '
                  'sigue en tu cuenta, pero deja de estar disponible para '
                  'gastar. Cuando quieras usarlo, retíralo de la meta.'
            : 'Estos ${AppFormat.moneda(activo!.reservado)} están apartados en '
                  '$enCuenta. El dinero no salió de la cuenta, pero no está '
                  'disponible para gastar.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// Historial de aportes y retiros de la meta: qué cuenta, cuándo y cuánto.
///
/// Existe para que la reserva sea reversible: cada fila se quita devolviendo el
/// dinero a su disponibilidad, en lugar de tener que compensarlo con un gasto
/// manual que falsearía el historial.
class _ListaRegistros extends StatelessWidget {
  final List<AbonoMeta> registros;
  final List<ActivoConSaldo> activos;
  final void Function(AbonoMeta registro) onQuitar;

  const _ListaRegistros({
    required this.registros,
    required this.activos,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final saldo = MetasLogic.saldoDeMeta(registros);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aportes y retiros',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (registros.isNotEmpty)
                Text(
                  '${registros.length} · ${AppFormat.moneda(saldo)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        if (registros.isEmpty)
          const _CardInfo(
            icon: Icons.savings_rounded,
            titulo: 'Sin aportes todavía',
            child: Text(
              'Cuando aportes a esta meta, el dinero no sale de la cuenta: '
              'queda reservado para este objetivo y deja de estar disponible '
              'para gastar. Cuando quieras usarlo, retíralo.',
            ),
          )
        else
          Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
            child: Column(
              children: [
                for (var i = 0; i < registros.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.borderSubtle,
                      indent: 16,
                      endIndent: 16,
                    ),
                  _FilaRegistro(
                    registro: registros[i],
                    nombreActivo: _nombreActivo(registros[i].activoId),
                    onQuitar: () => onQuitar(registros[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String? _nombreActivo(int? activoId) {
    if (activoId == null) return null;
    for (final activo in activos) {
      if (activo.id == activoId) return activo.nombre;
    }
    return null;
  }
}

class _FilaRegistro extends StatelessWidget {
  final AbonoMeta registro;
  final String? nombreActivo;
  final VoidCallback onQuitar;

  const _FilaRegistro({
    required this.registro,
    required this.nombreActivo,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final esAporte = registro.esAporte;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: esAporte ? AppColors.mintPale : AppColors.coral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              esAporte ? Icons.savings_rounded : Icons.undo_rounded,
              color: esAporte ? AppColors.primary : AppColors.coral,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esAporte ? 'Aporte' : 'Retiro',
                  style: Theme.of(context).textTheme.titleSmall!,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM yyyy').format(registro.fecha)} · '
                  '${nombreActivo ?? 'Cuenta eliminada'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${esAporte ? '+' : '−'}${AppFormat.moneda(registro.monto)}',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: esAporte ? AppColors.primary : AppColors.coral,
            ),
          ),
          IconButton(
            onPressed: onQuitar,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.coral,
            tooltip: esAporte ? 'Quitar aporte' : 'Quitar retiro',
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final MetaCalculo calculo;

  const _Encabezado({required this.calculo});

  @override
  Widget build(BuildContext context) {
    final meta = calculo.meta;
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
              meta.nombre,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labelFinalidad(meta.finalidad),
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (calculo.porcentajeProgreso / 100).clamp(0.0, 1.0),
                minHeight: 10,
                color: calculo.cumpleObjetivo
                    ? AppColors.orange
                    : AppColors.textOnPrimary,
                backgroundColor:
                    AppColors.textOnPrimary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${calculo.porcentajeProgreso.toStringAsFixed(0)}% ahorrado',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  meta.montoObjetivo == null
                      ? '${currency(calculo.saldo)} apartados'
                      : '${currency(calculo.saldo)} '
                          'de ${currency(meta.montoObjetivo!)}',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesgloseCalculo extends StatelessWidget {
  final MetaCalculo calculo;

  const _DesgloseCalculo({required this.calculo});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final meta = calculo.meta;

    if (meta.montoObjetivo == null) {
      return const _CardInfo(
        icon: Icons.info_outline_rounded,
        titulo: 'Ahorro sin meta fija',
        child: null,
      );
    }

    final filas = <_FilaDesglose>[];
    filas.add(_FilaDesglose(
      label: 'Monto objetivo',
      value: currency(meta.montoObjetivo!),
    ));
    filas.add(_FilaDesglose(
      label: 'Ahorrado a la fecha',
      value: currency(calculo.saldo),
    ));
    filas.add(_FilaDesglose(
      label: 'Falta por ahorrar',
      value: currency(calculo.montoFaltante!),
      destacado: true,
    ));

    if (meta.fechaEstimada == null) {
      filas.add(const _FilaDesglose(
        label: 'Fecha estimada',
        value: 'Sin fecha definida',
        valorGris: true,
      ));
    } else {
      final fecha = DateFormat('dd MMM yyyy').format(meta.fechaEstimada!);
      filas.add(_FilaDesglose(label: 'Fecha estimada', value: fecha));
      if ((calculo.semanasRestantes ?? 0) > 0) {
        filas.add(_FilaDesglose(
          label: 'Semanas restantes',
          value: '${calculo.semanasRestantes}',
        ));
        filas.add(_FilaDesglose(
          label: 'Ahorro sugerido por semana',
          value: currency(calculo.ahorroSemanal!),
          destacado: true,
        ));
      }
      if ((calculo.mesesRestantes ?? 0) > 0) {
        filas.add(_FilaDesglose(
          label: 'Meses restantes',
          value: '${calculo.mesesRestantes}',
        ));
        filas.add(_FilaDesglose(
          label: 'Ahorro sugerido por mes',
          value: currency(calculo.ahorroMensual!),
          destacado: true,
        ));
      }
      if ((calculo.semanasRestantes ?? 0) == 0 &&
          (calculo.mesesRestantes ?? 0) == 0) {
        filas.add(const _FilaDesglose(
          label: 'Tiempo restante',
          value: 'Fecha vencida',
          valorGris: true,
        ));
      }
    }

    if (calculo.cumpleObjetivo) {
      filas.add(const _FilaDesglose(
        label: 'Estado',
        value: 'Meta cumplida 🎉',
        destacado: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Desglose del cálculo',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
            color: destacado
                ? AppColors.primary
                : (valorGris ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _CardInfo extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final Widget? child;

  const _CardInfo({required this.icon, required this.titulo, this.child});

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
                  if (child != null) ...[
                    const SizedBox(height: 6),
                    child!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}