import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/logic/movimientos/movimientos_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _mov({
  required String tipo,
  required double monto,
  int? activoId,
  String categoria = 'otro',
}) {
  return Transaction(
    tipo: tipo,
    monto: monto,
    categoria: categoria,
    fecha: DateTime(2026, 3, 10),
    activoId: activoId,
    fechaCreacion: DateTime(2026, 3, 10),
  );
}

void main() {
  final monedaDe = <int?, String>{1: 'COP', 2: 'USD'};

  group('totales por moneda', () {
    test('agrupa ingresos y gastos por la moneda del activo', () {
      final movimientos = [
        _mov(tipo: 'ingreso', monto: 100000, activoId: 1),
        _mov(tipo: 'ingreso', monto: 50, activoId: 2),
        _mov(tipo: 'gasto', monto: 30000, activoId: 1),
        _mov(tipo: 'gasto', monto: 20, activoId: 2),
      ];

      expect(
        MovimientosLogic.totalIngresos(movimientos, monedaDe),
        {'COP': 100000, 'USD': 50},
      );
      expect(
        MovimientosLogic.totalGastos(movimientos, monedaDe),
        {'COP': 30000, 'USD': 20},
      );
    });

    test('los movimientos sin activo resoluble van a "sin moneda"', () {
      final movimientos = [
        _mov(tipo: 'gasto', monto: 10000),
        _mov(tipo: 'gasto', monto: 5000, activoId: 99),
      ];

      expect(
        MovimientosLogic.totalGastos(movimientos, monedaDe),
        {MovimientosLogic.monedaDesconocida: 15000},
      );
    });

    test('el balance resta solo dentro de cada moneda', () {
      final balance = MovimientosLogic.balanceNeto(
        {'COP': 100000, 'USD': 50},
        {'COP': 30000},
      );

      expect(balance, {'COP': 70000, 'USD': 50});
    });
  });
}
