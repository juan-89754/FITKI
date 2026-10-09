import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../activos/activos_providers.dart';
import 'gasto_fijo_form_screen.dart';
import 'presupuesto_activo_form_screen.dart';
import '../widgets/gastos_fijos_tab.dart';
import '../widgets/mes_navigator.dart';
import '../widgets/presupuesto_mensual_tab.dart';

/// Módulo de gastos.
///
/// Dos pestañas, cada una independiente: los gastos fijos (lo que se repite
/// cada mes) y el presupuesto por cuenta (cuánto llevas gastado de cada una).
/// El gasto hormiga ya no vive aquí: todo gasto se registra en Movimientos.
class PresupuestoScreen extends ConsumerStatefulWidget {
  const PresupuestoScreen({super.key});

  @override
  ConsumerState<PresupuestoScreen> createState() => _PresupuestoScreenState();
}

class _PresupuestoScreenState extends ConsumerState<PresupuestoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // El FAB cambia de texto según la pestaña, así que hay que repintarlo.
    _tabController.addListener(_alCambiarPestana);
  }

  void _alCambiarPestana() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_alCambiarPestana)
      ..dispose();
    super.dispose();
  }

  /// El FAB hace lo que corresponde a la pestaña visible: una crea un gasto
  /// fijo, la otra el límite de una cuenta.
  Future<void> _agregar() async {
    if (_tabController.index == 0) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GastoFijoFormScreen()),
      );
      return;
    }

    final activos =
        ref.read(activosConSaldoProvider);
    if (activos.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Crea una cuenta antes de definir un presupuesto',
        type: AppSnackbarType.info,
      );
      return;
    }
    final activo = activos.length == 1
        ? activos.first
        : await _elegirActivo(activos);
    if (activo == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresupuestoActivoFormScreen(activo: activo.activo),
      ),
    );
  }

  /// Pide la cuenta del presupuesto.
  ///
  /// Muestra el Saldo **Disponible** y no el total: es contra ese número contra el
  /// que se valida el límite, así que mostrar otro dejaría al usuario comparando
  /// el límite con una cifra que la app no le va a dejar alcanzar.
  Future<ActivoConSaldo?> _elegirActivo(List<ActivoConSaldo> activos) async {
    return showModalBottomSheet<ActivoConSaldo>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  '¿De qué cuenta es el presupuesto?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...activos.map(
                (a) => ListTile(
                  leading: const Icon(Icons.account_balance_rounded),
                  title: Text(a.nombre),
                  subtitle: a.reservado > 0
                      ? Text(
                          '${AppFormat.moneda(a.reservado)} reservados en metas',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: Text(
                    AppFormat.moneda(a.saldoDisponible),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, a),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gastos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textOnPrimary,
          unselectedLabelColor:
              AppColors.textOnPrimary.withValues(alpha: 0.65),
          indicatorColor: AppColors.orange,
          dividerColor: AppColors.textOnPrimary.withValues(alpha: 0.15),
          tabs: const [
            Tab(icon: Icon(Icons.autorenew_rounded), text: 'Gastos fijos'),
            Tab(icon: Icon(Icons.donut_small_rounded), text: 'Presupuesto'),
          ],
        ),
      ),
      body: Column(
        children: [
          const MesNavigator(),
          const AvisoMesNoActual(
            texto: 'Estás viendo otro mes: los pagos y el límite que se muestran '
                'son los de ese período, no los de hoy.',
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [GastosFijosTab(), PresupuestoMensualTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Gasto fijo' : 'Presupuesto',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }
}
