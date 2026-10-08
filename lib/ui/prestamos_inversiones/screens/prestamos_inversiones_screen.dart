import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/loan.dart';
import '../../../data/models/investment.dart';
import '../../../logic/prestamos/prestamos_logic.dart';
import '../../../logic/inversiones/inversiones_logic.dart';
import '../../../data/providers/shared_providers.dart';
import '../../movimientos/movimientos_providers.dart';
import '../prestamos_inversiones_providers.dart';
import 'prestamo_form_screen.dart';
import 'inversion_form_screen.dart';
import 'prestamo_detalle_screen.dart';
import 'inversion_detalle_screen.dart';

class PrestamosInversionesScreen extends ConsumerStatefulWidget {
  const PrestamosInversionesScreen({super.key});

  @override
  ConsumerState<PrestamosInversionesScreen> createState() =>
      _PrestamosInversionesScreenState();
}

class _PrestamosInversionesScreenState
    extends ConsumerState<PrestamosInversionesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Préstamos e inversiones'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textOnPrimary,
          unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.65),
          indicatorColor: AppColors.orange,
          dividerColor: AppColors.textOnPrimary.withValues(alpha: 0.15),
          tabs: const [
            Tab(
              icon: Icon(Icons.handshake_rounded),
              text: 'Préstamos',
            ),
            Tab(
              icon: Icon(Icons.trending_up_rounded),
              text: 'Inversiones',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PrestamosTab(),
          _InversionesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Nuevo préstamo' : 'Nueva inversión'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  void _agregar() {
    final esPrestamo = _tabController.index == 0;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) =>
            esPrestamo ? const PrestamoFormScreen() : const InversionFormScreen(),
      ),
    )
        .then((guardado) {
      if (guardado == true) {
        ref.invalidate(prestamosStreamProvider);
        ref.invalidate(inversionesStreamProvider);
        ref.invalidate(movimientosStreamProvider);
        ref.invalidate(activosStreamProvider);
      }
    });
  }
}

class _PrestamosTab extends ConsumerWidget {
  const _PrestamosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prestamosAsync = ref.watch(prestamosStreamProvider);

    return prestamosAsync.when(
      data: (prestamos) {
        if (prestamos.isEmpty) {
          return const _EstadoVacio(
            icon: Icons.handshake_rounded,
            titulo: 'No tienes préstamos aún',
            descripcion:
                'Registra dinero que prestaste a terceros\ny sigue sus pagos parciales.',
          );
        }

        const currency = AppFormat.moneda;
        final totalActivo = PrestamosLogic.totalPrestadoActivo(prestamos);
        final hoy = DateTime.now();
        final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: prestamos.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            if (index == 0) {
              return _ResumenCard(
                icon: Icons.currency_exchange_rounded,
                iconColor: AppColors.primary,
                iconBackground: AppColors.chipBackgroundPrimary,
                label: 'Total prestado activo',
                valor: currency(totalActivo),
                subtitulo: 'Préstamos pendientes de cobro',
              );
            }
            final prestamo = prestamos[index - 1];
            final estado = PrestamosLogic.estadoDe(prestamo);
            final vencido =
                estado != 'pagado_total' &&
                prestamo.fechaPagoEsperada.isBefore(hoySoloFecha);
            return _PrestamoCard(
              prestamo: prestamo,
              estado: estado,
              vencido: vencido,
              onTap: () => _abrirDetalle(context, ref, prestamo),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error al cargar préstamos: $e',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.coral,
          ),
        ),
      ),
    );
  }

  void _abrirDetalle(BuildContext context, WidgetRef ref, Loan prestamo) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(builder: (_) => PrestamoDetalleScreen(prestamo: prestamo)),
    )
        .then((cambio) {
      if (cambio == true) {
        ref.invalidate(prestamosStreamProvider);
        ref.invalidate(movimientosStreamProvider);
        ref.invalidate(activosStreamProvider);
      }
    });
  }
}

class _InversionesTab extends ConsumerWidget {
  const _InversionesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inversionesAsync = ref.watch(inversionesStreamProvider);

    return inversionesAsync.when(
      data: (inversiones) {
        if (inversiones.isEmpty) {
          return const _EstadoVacio(
            icon: Icons.trending_up_rounded,
            titulo: 'No tienes inversiones aún',
            descripcion:
                'Registra tus inversiones y compara\nla ganancia proyectada con la real.',
          );
        }

        const currency = AppFormat.moneda;
        final resumenes = InversionesLogic.resumenPorTipo(inversiones);
        final totalReservado = inversiones
            .where((inv) => inv.estaActiva)
            .fold<double>(0, (acumulado, inv) => acumulado + inv.montoInvertido);
        final totalResultado = inversiones.fold<double>(
          0,
          (acumulado, inv) => acumulado + (inv.gananciaObtenida ?? 0),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _ResumenCard(
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.oliveGreen,
              iconBackground: AppColors.chipBackgroundOlive,
              label: 'Capital reservado',
              valor: currency(totalReservado),
              subtitulo: 'Resultado: ${currency(totalResultado)}',
            ),
            const SizedBox(height: 16),
            for (final resumen in resumenes) ...[
              _HeaderGrupo(resumen: resumen),
              const SizedBox(height: 8),
              for (final inversion
                  in inversiones.where((inv) =>
                      InversionesLogic.tipoGrupo(inv) == resumen.tipo)) ...[
                _InversionCard(
                  inversion: inversion,
                  onTap: () => _abrirDetalle(context, ref, inversion),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error al cargar inversiones: $e',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.coral,
          ),
        ),
      ),
    );
  }

  void _abrirDetalle(
    BuildContext context,
    WidgetRef ref,
    Investment inversion,
  ) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => InversionDetalleScreen(inversion: inversion),
      ),
    )
        .then((cambio) {
      if (cambio == true) {
        ref.invalidate(inversionesStreamProvider);
        ref.invalidate(movimientosStreamProvider);
        ref.invalidate(activosStreamProvider);
      }
    });
  }
}

class _ResumenCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String valor;
  final String subtitulo;

  const _ResumenCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.valor,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      fontSize: 13,
                      color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                      ),
                    ),
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

class _PrestamoCard extends StatelessWidget {
  final Loan prestamo;
  final String estado;
  final bool vencido;
  final VoidCallback onTap;

  const _PrestamoCard({
    required this.prestamo,
    required this.estado,
    required this.vencido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final restante = PrestamosLogic.montoRestante(prestamo);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _iconoPrestamo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prestamo.nombreBeneficiario,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prestó ${currency(prestamo.montoPrestado)}',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ChipEstado(estado: estado),
                        if (estado != 'pagado_total') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              restante > 0
                                  ? 'Faltan ${currency(restante)}'
                                  : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    color: vencido
                                        ? AppColors.coral
                                        : AppColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconoPrestamo() {
    final backgroundColor = estado == 'pagado_total'
        ? AppColors.chipBackgroundPrimary
        : (vencido ? AppColors.chipBackgroundCoral : AppColors.mintPale);
    final iconColor = estado == 'pagado_total'
        ? AppColors.primary
        : (vencido ? AppColors.coral : AppColors.primary);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        estado == 'pagado_total'
            ? Icons.check_rounded
            : Icons.person_rounded,
        color: iconColor,
        size: 22,
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String estado;

  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    switch (estado) {
      case 'pagado_total':
        background = AppColors.chipBackgroundPrimary;
        foreground = AppColors.primary;
        break;
      case 'pagado_parcial':
        background = AppColors.chipBackgroundOlive;
        foreground = AppColors.oliveGreen;
        break;
      default:
        background = AppColors.chipBackgroundOrange;
        foreground = AppColors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        PrestamosLogic.labelEstado(estado),
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _HeaderGrupo extends StatelessWidget {
  final ResumenInversionPorTipo resumen;

  const _HeaderGrupo({required this.resumen});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            InversionesLogic.labelTipo(resumen.tipo),
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${resumen.cantidad} ${resumen.cantidad == 1 ? 'inversión' : 'inversiones'}',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency(resumen.totalInvertido),
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Ganancia: ${currency(resumen.gananciaTotal)}',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InversionCard extends StatelessWidget {
  final Investment inversion;
  final VoidCallback onTap;

  const _InversionCard({required this.inversion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    // Se proyecta a UN período del mismo tipo que la tasa declarada: si la
    // tasa es mensual, la ganancia aquí es lo que produce en un mes; si es
    // anual, en un año.
    final proyectada = InversionesLogic.gananciaProyectada(
      inversion,
      periodoProyeccion: inversion.periodoTasa,
      numeroPeriodos: 1,
    );
    final rendimiento = InversionesLogic.rendimientoReal(
      inversion,
      periodoProyeccion: inversion.periodoTasa,
    );

    final tieneTasa = inversion.tasaRendimiento != null;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currency(inversion.montoInvertido),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _ChipTasa(
                    texto: tieneTasa
                        ? '${inversion.tasaRendimiento!.toStringAsFixed(1)}% '
                            '${InversionesLogic.labelPeriodo(inversion.periodoTasa)}'
                        : 'Sin tasa',
                    esTasa: tieneTasa,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ganancia proyectada '
                '(${InversionesLogic.labelPeriodoCorto(inversion.periodoTasa)}): '
                '${tieneTasa ? currency(proyectada) : 'Sin tasa definida'}',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (rendimiento != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Obtenida: ${currency(rendimiento.gananciaObtenida)}',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: rendimiento.superaProyectada
                            ? AppColors.primary
                            : AppColors.coral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (tieneTasa) ...[
                      Text(
                        '(${rendimiento.superaProyectada ? '+' : '-'}'
                        '${currency(rendimiento.diferencia.abs())} '
                        'vs proyectada)',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: rendimiento.superaProyectada
                              ? AppColors.primary
                              : AppColors.coral,
                        ),
                      ),
                    ],
                  ],
                ),
              ] else if (inversion.gananciaObtenida != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Rendimiento real: Sin datos suficientes',
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(inversion.fecha),
                    style: Theme.of(context).textTheme.bodySmall!,
                  ),
                  const Spacer(),
                  _ChipEstadoInversion(activa: inversion.estaActiva),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipTasa extends StatelessWidget {
  final String texto;
  final bool esTasa;

  const _ChipTasa({required this.texto, required this.esTasa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: esTasa
            ? AppColors.chipBackgroundOlive
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: esTasa ? AppColors.oliveGreen : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ChipEstadoInversion extends StatelessWidget {
  final bool activa;

  const _ChipEstadoInversion({required this.activa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activa ? AppColors.chipBackgroundOlive : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activa ? 'Activa' : 'Finalizada',
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: activa ? AppColors.oliveGreen : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;

  const _EstadoVacio({
    required this.icon,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.mintPale,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}