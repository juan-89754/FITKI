import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/totales_por_moneda.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../data/models/asset.dart';
import '../../../data/providers/shared_providers.dart';
import '../activos_providers.dart';
import '../../home/tab_navigation.dart';
import '../../metas/metas_providers.dart';
import '../../asignaciones/asignacion_providers.dart';
import 'activo_form_screen.dart';

class ActivosScreen extends ConsumerWidget {
  const ActivosScreen({super.key});

  IconData _iconoParaTipo(String tipo) {
    switch (tipo) {
      case 'cuenta_bancaria':
        return Icons.account_balance_rounded;
      case 'billetera_digital':
        return Icons.account_balance_wallet_rounded;
      case 'efectivo':
        return Icons.money_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'cuenta_bancaria':
        return 'Cuenta bancaria';
      case 'billetera_digital':
        return 'Billetera digital';
      case 'efectivo':
        return 'Efectivo';
      default:
        return 'Otro';
    }
  }

/// Formatea un monto con el símbolo de su moneda.
  ///
  /// Es `static` porque la necesitan tanto la cabecera como las tarjetas, y
  /// duplicarlo haría que dos vistas del mismo número se mostraran distinto.
  static String _formatearMonto(double monto, String moneda) {
    final symbol = moneda == 'USD' ? 'US\$' : '\$';
    return AppFormat.moneda(monto, symbol: symbol);
  }

  void _abrirFormulario(BuildContext context, WidgetRef ref, {Asset? asset}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivoFormScreen(asset: asset),
      ),
    ).then((_) => ref.invalidate(activosStreamProvider));
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, Asset asset) async {
    final confirmado = await AppDialog.confirm(
      context: context,
      title: 'Eliminar activo',
      message: '¿Eliminar "${asset.nombre}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmado != true) return;
    try {
      await ref.read(activoRepositoryProvider).delete(asset.id!);
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
    ref.invalidate(activosStreamProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patrimonioTotalAsync = ref.watch(patrimonioTotalProvider);
    final disponiblesAsync = ref.watch(patrimonioDisponibleTotalProvider);
    final activosAsync = ref.watch(activosConSaldoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Activos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Column(
        children: [
          _PatrimonioHeader(
            patrimonioTotal: patrimonioTotalAsync,
            disponibleTotal: disponiblesAsync,
            hayReservas: ref.watch(registrosDeMetasProvider).asData?.value
                .any((r) => r.montoConSigno != 0) ?? false,
          ),
          Expanded(
            child: activosAsync.isEmpty
                ? EmptyState(
                    icono: Icons.account_balance_rounded,
                    titulo: 'No tienes activos registrados',
                    descripcion: 'Agrega tu primera cuenta, billetera o '
                        'efectivo\npara empezar a ver tu patrimonio.',
                    etiquetaAccion: 'Agregar activo',
                    onAccion: () => _abrirFormulario(context, ref),
                  )
                : ListView.separated(
                    controller: ref.read(
                      tabScrollControllersProvider,
                    )[TabIndex.activos],
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: activosAsync.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final activo = activosAsync[index];
                      return _ActivoCard(
                        activo: activo,
                        icono: _iconoParaTipo(activo.activo.tipo),
                        labelTipo: _labelTipo(activo.activo.tipo),
                        onTap: () => _abrirFormulario(
                          context,
                          ref,
                          asset: activo.activo,
                        ),
                        onEliminar: () => _confirmarEliminar(
                          context,
                          ref,
                          activo.activo,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo activo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }
}

class _PatrimonioHeader extends StatelessWidget {
  final Map<String, double> patrimonioTotal;
  final Map<String, double> disponibleTotal;
  final bool hayReservas;

  const _PatrimonioHeader({
    required this.patrimonioTotal,
    required this.disponibleTotal,
    required this.hayReservas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patrimonio Total',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 4),
          TotalesPorMoneda(
            totales: patrimonioTotal,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnPrimary,
            ),
          ),
          // El patrimonio de arriba es la suma de los saldos totales: cuenta
          // también el dinero apartado en metas. Este es el único número que
          // responde "¿cuánto puedo gastar?", y por eso solo aparece cuando hay
          // reservas: si no hay, disponible y total serían el mismo número dos
          // veces.
          if (hayReservas) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${_totalesReservadosEnLinea()} reservados en metas · '
                      '${AppFormat.totalesEnLinea(disponibleTotal)} disponibles',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textOnPrimary,
                      ),
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

  /// La parte reservada en metas, desglosada por moneda y sin cerrar en cero:
  /// solo se listan las monedas donde realmente hay algo reservado.
  String _totalesReservadosEnLinea() {
    final reservados = <String, double>{};
    for (final entrada in patrimonioTotal.entries) {
      final reservado = entrada.value - (disponibleTotal[entrada.key] ?? 0);
      if (reservado != 0) reservados[entrada.key] = reservado;
    }
    return AppFormat.totalesEnLinea(reservados);
  }
}

class _ActivoCard extends ConsumerWidget {
  final ActivoConSaldo activo;
  final IconData icono;
  final String labelTipo;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _ActivoCard({
    required this.activo,
    required this.icono,
    required this.labelTipo,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = activo.activo;
    final activoId = asset.id;

    // Lo comprometido en planes AFCA. Es un desglose distinto del de metas:
    // un plan no descuenta el saldo disponible (solo le da destino al dinero),
    // así que no puede mezclarse con "reservado" sin mentirle al usuario.
    final comprometido =
        activoId == null ? 0.0 : ref.watch(saldosActivoProvider(activoId)).comprometido;

    // Solo tiene sentido desglosar cuando hay algo reservado: si no, mostrar
    // "disponible $X" repetido bajo un total de $X solo agrega ruido.
    final hayReserva =
        activo.reservado > 0 ||
        activo.reservadoInversiones > 0 ||
        comprometido > 0;
    final reservaTexto = [
      if (activo.reservado > 0)
        '${ActivosScreen._formatearMonto(activo.reservado, activo.moneda)} en metas',
      if (activo.reservadoInversiones > 0)
        '${ActivosScreen._formatearMonto(activo.reservadoInversiones, activo.moneda)} en inversiones',
      if (comprometido > 0)
        '${ActivosScreen._formatearMonto(comprometido, activo.moneda)} destinado en planes',
    ].join(' · ');

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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.nombre,
                      style: Theme.of(context).textTheme.titleMedium!,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hayReserva
                          ? '$labelTipo · $reservaTexto'
                          : labelTipo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ActivosScreen._formatearMonto(
                      hayReserva ? activo.saldoDisponible : activo.saldoTotal,
                      activo.moneda,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(color: AppColors.primary),
                  ),
                  if (hayReserva)
                    Text(
                      'de ${ActivosScreen._formatearMonto(activo.saldoTotal, activo.moneda)}',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                onSelected: (value) {
                  if (value == 'eliminar') onEliminar();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'eliminar',
                    child: Text(
                      'Eliminar',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: AppColors.coral,
                      ),
                    ),
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