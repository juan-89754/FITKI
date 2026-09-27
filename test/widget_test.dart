import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitki/main.dart';
import 'package:fitki/data/models/asset.dart';
import 'package:fitki/data/models/debt.dart';
import 'package:fitki/data/models/financial_goal.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/data/providers/shared_providers.dart';
import 'package:fitki/ui/deudas/deudas_providers.dart';
import 'package:fitki/ui/metas/metas_providers.dart';
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
          ],
          child: const FitkiApp(),
        ),
      );
      await tester.pump();

      expect(
        find.text('Este es el panorama de tus finanzas.'),
        findsOneWidget,
      );
      expect(find.text('PATRIMONIO TOTAL'), findsOneWidget);

      // Desmonta el árbol para cerrar cualquier recurso pendiente.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}