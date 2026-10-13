import 'package:fitki/logic/carga_deuda.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcularCargaDeuda', () {
    test('calcula el porcentaje sobre los ingresos del mes', () {
      final carga = calcularCargaDeuda(40000, 100000, umbral: 0.40);

      expect(carga.porcentaje, 40);
      expect(carga.excedeUmbral, isFalse);
    });

    test('sin ingresos no hay porcentaje ni alerta', () {
      final carga = calcularCargaDeuda(40000, 0, umbral: 0.40);

      expect(carga.porcentaje, isNull);
      expect(carga.excedeUmbral, isFalse);
    });

    test('marca la alerta cuando supera el umbral', () {
      final carga = calcularCargaDeuda(60000, 100000, umbral: 0.40);

      expect(carga.porcentaje, 60);
      expect(carga.excedeUmbral, isTrue);
    });
  });
}
