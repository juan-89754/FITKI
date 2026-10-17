import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/shared_providers.dart';
import '../../logic/asignaciones/asignacion_logic.dart';
import '../../shared/format/app_format.dart';
import '../../shared/theme/app_colors.dart';
import 'asignacion_providers.dart';
import 'plan_asignacion_screen.dart';
import 'plan_form_screen.dart';

/// Módulo AFCA: Asignación Flexible y Control de Activos.
///
/// En lugar de un límite rígido por mes, acá se decide a qué categoría de
/// gasto va cada parte del dinero de una cuenta, sin fecha de vencimiento. Lo
/// gastado de cada bolsillo se deriva de los movimientos reales, así que el
/// plan y lo que pasó no pueden desincronizarse.
///
/// La pantalla responde tres preguntas: a qué cuenta le toca, cuánto de ese
/// dinero ya tiene destino y en qué se está yendo.
class AsignacionScreen extends ConsumerWidget {
  const AsignacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenes = ref.watch(resumenesPlanProvider);
    final activos =
        ref.watch(activosStreamProvider).asData?.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Asignación'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(planesAsignacionStreamProvider);
          ref.invalidate(detallesAsignacionStreamProvider);
        },
        child: resumenes.isEmpty
            ? _Vacio(
                icono: Icons.donut_small_rounded,
                titulo: 'Todavía no hay planes',
                mensaje:
                    'Reparte el dinero de una cuenta entre las categorías en '
                    'las que lo gastas. Sin meses que vencen y sin tener que '
                    'adivinar de antemano cuánto saldrá cada cosa.',
                accion: activos.isEmpty ? null : () => _crearPlan(context),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _SaldosCuentas(),
                  const SizedBox(height: 18),
                  for (final resumen in resumenes)
                    _TarjetaPlan(
                      resumen: resumen,
                      alAbrir: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlanAsignacionScreen(planId: resumen.plan.id!),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: resumenes.isEmpty && activos.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _crearPlan(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
    );
  }

  Future<void> _crearPlan(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlanFormScreen()),
    );
  }
}

/// Cuenta real frente a lo que ya está comprometido en planes con fondos.
///
/// Repartir no mueve el dinero: el saldo de la cuenta no cambia al asignarlo,
/// lo que cambia es cuánto de él ya está destinado. Por eso el saldo real y el
/// comprometido se muestran separados y nunca se suman.
class _SaldosCuentas extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planes =
        ref.watch(planesAsignacionStreamProvider).asData?.value ?? const [];
    final activos =
        ref.watch(activosStreamProvider).asData?.value ?? const [];

    final idsConPlanes = <int>{};
    for (final plan in planes) {
      final id = plan.activoId;
      if (id != null) idsConPlanes.add(id);
    }
    if (idsConPlanes.isEmpty) return const SizedBox.shrink();

    final cuentas = activos.where((a) => idsConPlanes.contains(a.id)).toList();
    if (cuentas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dinero de tus cuentas',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lo que hay, lo que ya tiene destino y lo que sigue libre.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        for (final cuenta in cuentas)
          _FilaCuenta(
            nombre: cuenta.nombre,
            saldos: ref.watch(saldosActivoProvider(cuenta.id!)),
          ),
      ],
    );
  }
}

class _FilaCuenta extends StatelessWidget {
  const _FilaCuenta({required this.nombre, required this.saldos});

  final String nombre;
  final SaldosActivo saldos;

  @override
  Widget build(BuildContext context) {
    final libreNegativo = saldos.libre < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                AppFormat.moneda(saldos.saldoReal),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _CifraCuenta(
                etiqueta: 'En la cuenta',
                valor: AppFormat.moneda(saldos.saldoReal),
                color: AppColors.textPrimary,
              ),
              const Spacer(),
              _CifraCuenta(
                etiqueta: 'Asignado',
                valor: AppFormat.moneda(saldos.comprometido),
                color: AppColors.textSecondary,
              ),
              const Spacer(),
              _CifraCuenta(
                etiqueta: libreNegativo ? 'Sobre-asignado' : 'Libre',
                valor: AppFormat.moneda(saldos.libre.abs()),
                color: libreNegativo ? AppColors.coral : AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CifraCuenta extends StatelessWidget {
  const _CifraCuenta({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

/// Un plan: qué tiene destinado y en qué se le está yendo el dinero.
class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({required this.resumen, required this.alAbrir});

  final ResumenPlan resumen;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final plan = resumen.plan;
    final sinAsignar = resumen.sinAsignar != 0;
    final cobertura = plan.montoTotalObjetivo <= 0
        ? 0.0
        : (resumen.totalAsignado / plan.montoTotalObjetivo).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: alAbrir,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  plan.archivado
                      ? Icons.archive_outlined
                      : Icons.donut_small_rounded,
                  size: 20,
                  color: plan.archivado
                      ? AppColors.textSecondary
                      : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.nombre,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (plan.esProyectado) const _Chip(texto: 'Proyectado'),
                if (plan.archivado) const _Chip(texto: 'Archivado', gris: true),
              ],
            ),
            if (plan.activoId != null) ...[
              const SizedBox(height: 6),
              _NombreCuenta(activoId: plan.activoId!),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: cobertura,
                minHeight: 9,
                backgroundColor: AppColors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  plan.archivado ? AppColors.textSecondary : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CifraPlan(
                  etiqueta: 'Destinado',
                  valor: AppFormat.moneda(resumen.totalAsignado),
                  color: AppColors.textPrimary,
                ),
                _CifraPlan(
                  etiqueta: 'Plan',
                  valor: AppFormat.moneda(plan.montoTotalObjetivo),
                  color: AppColors.textSecondary,
                ),
                _CifraPlan(
                  etiqueta: sinAsignar ? 'Sin destinar' : 'Gastado',
                  valor: AppFormat.moneda(
                    sinAsignar
                        ? resumen.sinAsignar.abs()
                        : resumen.gastadoTotal,
                  ),
                  color: sinAsignar ? AppColors.coral : AppColors.textPrimary,
                ),
              ],
            ),
            if (sinAsignar && !plan.archivado) ...[
              const SizedBox(height: 10),
              Text(
                resumen.sinAsignar < 0
                    ? 'Destinaste más de lo que vale el plan.'
                    : 'Todavía falta repartir ${AppFormat.moneda(resumen.sinAsignar)} entre categorías.',
                style: const TextStyle(color: AppColors.coral, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, this.gris = false});

  final String texto;
  final bool gris;

  @override
  Widget build(BuildContext context) {
    final colorFondo = gris ? AppColors.surfaceSecondary : AppColors.mintPale;
    final colorTexto = gris ? AppColors.textSecondary : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(color: colorTexto, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NombreCuenta extends ConsumerWidget {
  const _NombreCuenta({required this.activoId});

  final int activoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreActivoProvider(activoId));
    return Text(
      nombre ?? 'Cuenta eliminada',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
    );
  }
}

class _CifraPlan extends StatelessWidget {
  const _CifraPlan({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icono, size: 36, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (accion != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: accion,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Crear mi primer plan'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
