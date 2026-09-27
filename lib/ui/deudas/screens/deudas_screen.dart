import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../data/models/debt.dart';
import '../../../logic/carga_deuda.dart';
import '../../../logic/deudas/deudas_logic.dart';
import '../deudas_providers.dart';
import 'deuda_detalle_screen.dart';
import 'deuda_form_screen.dart';

class DeudasScreen extends ConsumerWidget {
  const DeudasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudasAsync = ref.watch(deudasStreamProvider);
    final cargaAsync = ref.watch(cargaDeudaProvider);
    final totalPendiente = ref.watch(totalDeudaPendienteProvider);
    final progresoGlobal = ref.watch(progresoDeudaGlobalProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Deudas'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: deudasAsync.when(
        data: (deudas) {
          if (deudas.isEmpty) {
            return _EstadoVacio(
              onAgregar: () => _abrirFormulario(context, ref),
            );
          }
          final activas = deudas
              .where((deuda) => deuda.montoPendiente > 0)
              .toList();
          final saldadas = deudas
              .where((deuda) => deuda.montoPendiente <= 0)
              .toList();
          return _contenido(
            context,
            ref,
            activas,
            saldadas,
            cargaAsync,
            totalPendiente,
            progresoGlobal,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar deudas: $e',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.coral,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva deuda'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    WidgetRef ref,
    List<Debt> activas,
    List<Debt> saldadas,
    AsyncValue<CargaDeuda> cargaAsync,
    double totalPendiente,
    double progresoGlobal,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _TotalDeuda(
          totalPendiente: totalPendiente,
          progreso: progresoGlobal,
          numActivas: activas.length,
          numSaldadas: saldadas.length,
        ),
        const SizedBox(height: 16),
        _AlertaCargaDeuda(cargaAsync: cargaAsync),
        const SizedBox(height: 16),
        if (activas.isEmpty)
          _sinDeudasActivas(context, ref)
        else ...[
          Text(
            'Deudas activas',
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...activas.map(
            (deuda) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeudaCard(
                deuda: deuda,
                onTap: () => _abrirDetalle(context, ref, deuda),
              ),
            ),
          ),
        ],
        if (saldadas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Saldadas',
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...saldadas.map(
            (deuda) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: 0.55,
                child: _DeudaCard(
                  deuda: deuda,
                  onTap: () => _abrirDetalle(context, ref, deuda),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sinDeudasActivas(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.mintPale,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No tienes deudas activas',
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Registra una deuda para llevar su plan de pagos.',
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  void _abrirFormulario(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DeudaFormScreen()))
        .then((guardado) {
      if (guardado == true) ref.invalidate(deudasStreamProvider);
    });
  }

  void _abrirDetalle(BuildContext context, WidgetRef ref, Debt deuda) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DeudaDetalleScreen(deuda: deuda)))
        .then((cambio) {
      if (cambio == true) ref.invalidate(deudasStreamProvider);
    });
  }
}

class _TotalDeuda extends StatelessWidget {
  final double totalPendiente;
  final double progreso;
  final int numActivas;
  final int numSaldadas;

  const _TotalDeuda({
    required this.totalPendiente,
    required this.progreso,
    required this.numActivas,
    required this.numSaldadas,
  });

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;
    final porcentaje = (progreso * 100).toStringAsFixed(0);

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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.textOnPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total de deuda',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      numActivas == 0
                          ? 'Sin deudas activas'
                          : '$numActivas ${numActivas == 1 ? 'deuda activa' : 'deudas activas'}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currency(totalPendiente),
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                color: AppColors.orange,
                backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  numActivas == 0
                      ? 'Todo pagado'
                      : 'Progreso de pago general',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  '$porcentaje%',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
            if (numSaldadas > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$numSaldadas ${numSaldadas == 1 ? 'deuda saldada' : 'deudas saldadas'}',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertaCargaDeuda extends StatelessWidget {
  final AsyncValue<CargaDeuda> cargaAsync;

  const _AlertaCargaDeuda({required this.cargaAsync});

  @override
  Widget build(BuildContext context) {
    final carga = cargaAsync.asData?.value;
    if (carga == null) return const SizedBox.shrink();

    const currency = AppFormat.moneda;

    if (!carga.excedeUmbral) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Carga de deuda: ${carga.porcentaje.toStringAsFixed(0)}% '
                'de tus ingresos del mes '
                '(${currency(carga.cuotaMensualTotal)} en cuotas).',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final umbral = (carga.umbral * 100).toStringAsFixed(0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.coral, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Alerta: tu carga de deuda es del '
              '${carga.porcentaje.toStringAsFixed(0)}% de los ingresos del '
              'mes. Supera el umbral configurado del $umbral%.',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeudaCard extends StatelessWidget {
  final Debt deuda;
  final VoidCallback onTap;

  const _DeudaCard({required this.deuda, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const currency = AppFormat.moneda;

    final saldada = deuda.montoPendiente <= 0;
    final proximoPago = deuda.fechaProximoPago;
    // Vencida solo si el próximo pago es anterior a HOY: se compara contra el
    // inicio del día (no contra la hora actual) para no marcar como vencida
    // una deuda cuyo pago vence hoy.
    final ahora = DateTime.now();
    final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day);
    final vencida = proximoPago != null &&
        proximoPago.isBefore(hoyInicio) &&
        !saldada;

    final progreso = DeudasLogic.progresoPago(deuda);
    final pagado = DeudasLogic.montoPagado(deuda);
    final inicial = DeudasLogic.montoInicialOf(deuda);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: vencida
              ? AppColors.coral.withValues(alpha: 0.5)
              : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: saldada
                          ? AppColors.surfaceSecondary
                          : AppColors.mintPale,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      saldada
                          ? Icons.check_rounded
                          : Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deuda.nombreAcreedor,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (deuda.plazo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            deuda.plazo!,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                proximoPago == null
                                    ? 'Sin fecha de pago'
                                    : 'Próximo pago: '
                                        '${DateFormat('dd MMM yyyy').format(proximoPago)}',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                      color: vencida
                                          ? AppColors.coral
                                          : AppColors.textSecondary,
                                      fontWeight: vencida
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        saldada ? 'Saldada' : 'Pendiente',
                        style: Theme.of(context).textTheme.bodySmall!,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency(deuda.montoPendiente),
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: saldada
                              ? AppColors.primary
                              : AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 8,
                      color: saldada ? AppColors.primary : AppColors.coral,
                      backgroundColor: AppColors.surfaceSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pagado: ${currency(pagado)} de ${currency(inicial)}',
                        style: Theme.of(context).textTheme.bodySmall!,
                      ),
                      Text(
                        '${(progreso * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: saldada ? AppColors.primary : AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final VoidCallback onAgregar;

  const _EstadoVacio({required this.onAgregar});

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
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes deudas registradas',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra una deuda para seguir tu plan\nde pagos y tu carga financiera.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}