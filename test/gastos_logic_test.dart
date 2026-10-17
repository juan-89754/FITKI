import 'package:fitki/data/models/loan.dart';
import 'package:fitki/data/models/transaction.dart';
import 'package:fitki/logic/gastos/gastos_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de la lógica pura de gastos.
///
/// `GastosLogic` no toca base de datos ni widgets, así que se puede testear
/// entero sin emulador. Acá vive la aritmética que el usuario ve: cuánto se
/// gastó por categoría y su promedio histórico. Un error acá no rompe la app,
/// la hace mentir con los números, que es peor.

Transaction _movimiento({
  required int activoId,
  required double monto,
  String tipo = Transaction.tipoGasto,
  String categoria = 'alimentacion',
  DateTime? fecha,
}) {
  return Transaction(
    tipo: tipo,
    monto: monto,
    categoria: categoria,
    fecha: fecha ?? DateTime(2026, 3, 15),
    activoId: activoId,
    fechaCreacion: DateTime(2026, 3, 15),
  );
}

void main() {
  group('gastadoPorCategoria', () {
    test('acumula por categoría solo en el mes pedido', () {
      final resultado = GastosLogic.gastadoPorCategoria(
        movimientos: [
          _movimiento(activoId: 1, monto: 10000, categoria: 'alimentacion'),
          _movimiento(
            activoId: 1,
            monto: 15000,
            categoria: 'alimentacion',
            fecha: DateTime(2026, 3, 30),
          ),
          _movimiento(activoId: 2, monto: 20000, categoria: 'transporte'),
          _movimiento(
            activoId: 1,
            monto: 80000,
            categoria: 'alimentacion',
            fecha: DateTime(2026, 1, 5),
          ),
        ],
        mes: 3,
        anio: 2026,
      );

      expect(resultado['alimentacion'], 25000);
      expect(resultado['transporte'], 20000);
    });

    test('ignora ingresos y préstamos a terceros', () {
      final resultado = GastosLogic.gastadoPorCategoria(
        movimientos: [
          _movimiento(activoId: 1, monto: 10000),
          _movimiento(
            activoId: 1,
            monto: 100000,
            categoria: Loan.categoriaPrestamo,
          ),
          _movimiento(
            activoId: 1,
            monto: 90000,
            tipo: Transaction.tipoIngreso,
          ),
        ],
        mes: 3,
        anio: 2026,
      );

      expect(resultado['alimentacion'], 10000);
      expect(resultado.containsKey(Loan.categoriaPrestamo), isFalse);
    });
  });

  group('promedioMensualCategoria', () {
    test('promedia solo los meses con gasto', () {
      // Enero y marzo con gasto, febrero sin nada: el promedio es (100 + 300)/2.
      final promedio = GastosLogic.promedioMensualCategoria(
        movimientos: [
          _movimiento(activoId: 1, monto: 100, fecha: DateTime(2026, 1, 10)),
          _movimiento(activoId: 1, monto: 300, fecha: DateTime(2026, 3, 10)),
          // Otra categoría: no cuenta.
          _movimiento(
            activoId: 1,
            monto: 999,
            categoria: 'transporte',
            fecha: DateTime(2026, 3, 10),
          ),
          // Fuera de la ventana de 3 meses.
          _movimiento(activoId: 1, monto: 5000, fecha: DateTime(2025, 1, 10)),
        ],
        categoria: 'alimentacion',
        mes: 4,
        anio: 2026,
      );

      expect(promedio, 200);
    });

    test('devuelve null sin historial en la ventana', () {
      final promedio = GastosLogic.promedioMensualCategoria(
        movimientos: [
          _movimiento(activoId: 1, monto: 5000, fecha: DateTime(2024, 1, 10)),
        ],
        categoria: 'alimentacion',
        mes: 6,
        anio: 2026,
      );

      expect(promedio, isNull);
    });
  });
}
