import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitki/main.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/debt.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/abono_meta.dart';
import 'package:fitki/data/models/investment.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/providers/shared_providers.dart';
import 'package:fitki/ui/deudas/deudas_providers.dart';
import 'package:fitki/ui/metas/metas_providers.dart';
import 'package:fitki/ui/prestamos_inversiones/prestamos_inversiones_providers.dart';
import 'package:fitki/ui/movimientos/movimientos_providers.dart';

void main() {
  testWidgets(
    'Smoke test: la app arranca y renderiza la pantalla de inicio',
    (WidgetTester tester) async {
      // Se sobreescriben los streams periódicos que consume HomeScreen para
      // que el test no dependa de sqflite ni deje timers pendientes.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activosStreamProvider.overrideWith(
              (ref) => Stream.value(const <Asset>[]),
            ),
            movimientosStreamProvider.overrideWith(
              (ref) => Stream.value(const <Transaction>[]),
            ),
            metasStreamProvider.overrideWith(
              (ref) => Stream.value(const <FinancialGoal>[]),
            ),
            deudasStreamProvider.overrideWith(
              (ref) => Stream.value(const <Debt>[]),
            ),
            perfilStreamProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            // El encabezado calcula el disponible, que descuenta lo reservado en
            // metas. Sin este override el test cierra con timers de sqflite
            // pendientes, porque esa promesa nunca termina en `flutter test`.
            registrosDeMetasProvider.overrideWith(
              (ref) => Stream.value(const <AbonoMeta>[]),
            ),
            inversionesStreamProvider.overrideWith(
              (ref) => Stream.value(const <Investment>[]),
            ),
          ],
          child: const FitkiApp(),
        ),
      );
      await tester.pump();

      expect(
        find.text('Este es el panorama de tus finanzas.'),
        findsOneWidget,
      );
      // El encabezado muestra únicamente el disponible: la pregunta del home es
      // cuánto hay para gastar, y el dinero apartado en metas no lo es aunque
      // siga siendo tuyo. El patrimonio total se movió a las tarjetas de abajo.
      expect(find.text('DISPONIBLE PARA GASTAR'), findsOneWidget);
      expect(find.text('Reservado en metas'), findsNothing);
      expect(find.text('PATRIMONIO TOTAL'), findsNothing);

      // Fitki no tiene pantalla de bloqueo: la app entra directa al inicio, sin
      // pedir PIN ni biometría ni al arrancar ni al volver de segundo plano.
      expect(find.textContaining('PIN'), findsNothing);
      expect(find.textContaining('Ingresa tu PIN'), findsNothing);
      expect(find.textContaining('información está protegida'), findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsNothing);

      // Desmonta el árbol para cerrar cualquier recurso pendiente.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'volver de segundo plano no monta ninguna pantalla de desbloqueo',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activosStreamProvider.overrideWith(
              (ref) => Stream.value(const <Asset>[]),
            ),
            movimientosStreamProvider.overrideWith(
              (ref) => Stream.value(const <Transaction>[]),
            ),
            metasStreamProvider.overrideWith(
              (ref) => Stream.value(const <FinancialGoal>[]),
            ),
            deudasStreamProvider.overrideWith(
              (ref) => Stream.value(const <Debt>[]),
            ),
            perfilStreamProvider.overrideWith((ref) => Stream.value(null)),
            // Ver el smoke test de arriba: el disponible del encabezado lee los
            // registros de las metas.
            registrosDeMetasProvider.overrideWith(
              (ref) => Stream.value(const <AbonoMeta>[]),
            ),
            inversionesStreamProvider.overrideWith(
              (ref) => Stream.value(const <Investment>[]),
            ),
          ],
          child: const FitkiApp(),
        ),
      );
      await tester.pump();

      // Simula la ida y vuelta a segundo plano. Antes, AppGate escuchaba este
      // ciclo de vida y volaba a la pantalla de bloqueo. La cadena completa
      // respeta las transiciones que valida el binding:
      // resumed -> inactive -> hidden -> paused -> hidden -> inactive -> resumed.
      for (final estado in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Este es el panorama de tus finanzas.'),
        findsOneWidget,
      );
      expect(find.textContaining('PIN'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
