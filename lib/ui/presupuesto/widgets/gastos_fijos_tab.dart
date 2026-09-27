import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/asset.dart';
import '../../../data/models/gasto_fijo.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../logic/gastos/gastos_logic.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/theme/app_colors.dart';
import '../presupuesto_providers.dart';
import '../screens/gasto_fijo_form_screen.dart';
import 'pagar_gastos_fijos_sheet.dart';

/// Lista de gastos fijos: primero lo que falta pagar este mes, después las
/// plantillas registradas.
class GastosFijosTab extends ConsumerWidget {
  const GastosFijosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(pendientesDelMesProvider);
    final plantillasAsync = ref.watch(gastosFijosStreamProvider);
    final activos = ref.watch(activosStreamProvider).asData?.value ?? const <Asset>[];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(gastosFijosStreamProvider);
        ref.invalidate(pagosDelMesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          pendientesAsync.when(
            loading: () => const _Cargando(),
            error: (e, _) =>
                const _ErrorMsg(mensaje: 'No se pudieron cargar los pagos'),
            data: (pendientes) => _TarjetaPendientes(
              pendientes: pendientes,
              alPagar: () => mostrarHojaDePagos(context, ref, pendientes),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus gastos fijos',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                '${plantillasAsync.asData?.value.length ?? 0}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          plantillasAsync.when(
            loading: () => const _Cargando(),
            error: (e, _) => const _ErrorMsg(
              mensaje: 'No se pudieron cargar los gastos fijos',
            ),
            data: (plantillas) => plantillas.isEmpty
                ? const _Vacio(
                    icono: Icons.autorenew_rounded,
                    titulo: 'Todavía no tienes gastos fijos',
                    mensaje:
                        'Registra aquí lo que pagas todos los meses (internet, '
                        'luz, arriendo) y la app te arma solo la lista de lo '
                        'que toca pagar cada mes, sin que tengas que escribir '
                        'nada.',
                  )
                : Column(
                    children: [
                      for (final plantilla in plantillas)
                        _TarjetaPlantilla(
                          plantilla: plantilla,
                          activos: activos,
                          alEditar: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GastoFijoFormScreen(gasto: plantilla),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPendientes extends StatelessWidget {
  const _TarjetaPendientes({required this.pendientes, required this.alPagar});

  final List<PendientePago> pendientes;
  final VoidCallback alPagar;

  @override
  Widget build(BuildContext context) {
    final total = pendientes.fold<double>(
      0.0,
      (acc, p) => acc + p.montoSugerido,
    );
    final hayPendientes = pendientes.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available_rounded,
                color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Por pagar este mes',
                style: TextStyle(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppFormat.moneda(total),
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hayPendientes
                ? '${pendientes.length} ${pendientes.length == 1 ? 'gasto fijo' : 'gastos fijos'} sin registrar'
                : 'No tienes nada pendiente de pago',
            style: TextStyle(
              color: AppColors.textOnPrimary.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          if (hayPendientes) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: alPagar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textOnPrimary,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Registrar pagos'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaPlantilla extends ConsumerWidget {
  const _TarjetaPlantilla({
    required this.plantilla,
    required this.activos,
    required this.alEditar,
  });

  final GastoFijo plantilla;
  final List<Asset> activos;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Asset? activo;
    for (final a in activos) {
      if (a.id == plantilla.activoId) {
        activo = a;
        break;
      }
    }
    final oscurecido = !plantilla.habilitado;

    return Opacity(
      opacity: oscurecido ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          onTap: alEditar,
          leading: Icon(
            iconoCategoria(plantilla.categoria),
            color: AppColors.primary,
          ),
          title: Text(
            plantilla.nombre,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${labelCategoria(plantilla.categoria)} · día ${plantilla.diaPago}'
            '${activo != null ? ' · ${activo.nombre}' : ' · sin cuenta'}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormat.moneda(plantilla.montoEstimado),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (plantilla.montoVariable)
                Text(
                  'precio variable',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.titulo, required this.mensaje});

  final IconData icono;
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 34, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorMsg extends StatelessWidget {
  const _ErrorMsg({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          mensaje,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
