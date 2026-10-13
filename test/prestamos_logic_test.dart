import 'package:fitki/data/models/loan.dart';
import 'package:fitki/logic/prestamos/prestamos_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Loan _prestamo({required double prestado, double pagado = 0}) {
  return Loan(
    nombreBeneficiario: 'Ana',
    montoPrestado: prestado,
    montoPagado: pagado,
    fechaPrestamo: DateTime(2026, 1, 1),
    fechaPagoEsperada: DateTime(2026, 2, 1),
    fechaCreacion: DateTime(2026, 1, 1),
  );
}

void main() {
  group('totalPrestadoActivo', () {
    test('suma lo que RESTA cobrar, no el monto original', () {
      final total = PrestamosLogic.totalPrestadoActivo([
        _prestamo(prestado: 1000, pagado: 400),
        _prestamo(prestado: 500),
        _prestamo(prestado: 300, pagado: 300),
      ]);

      expect(total, 1100);
    });

    test('sin préstamos activos es cero', () {
      expect(
        PrestamosLogic.totalPrestadoActivo([
          _prestamo(prestado: 200, pagado: 200),
        ]),
        0,
      );
    });
  });
}
