import 'package:flutter_test/flutter_test.dart';

import 'package:fitki/data/models/categoria_personalizada.dart';
import 'package:fitki/logic/categorias/categoria_labels.dart';

void main() {
  const gastoPersona = CategoriaPersonalizada(
    nombre: 'Mascotas',
    icono: 'pets_rounded',
    tipo: 'gasto',
  );

  group('resolverCategoriaDeNombre', () {
    test('respeta el slug de una categoría fija', () {
      expect(
        resolverCategoriaDeNombre(
          nombre: 'transporte',
          tipo: 'gasto',
          existentes: [gastoPersona],
        ),
        'transporte',
      );
    });

    test('reconoce la etiqueta de una categoría fija y devuelve el slug', () {
      expect(
        resolverCategoriaDeNombre(
          nombre: 'Transporte',
          tipo: 'gasto',
          existentes: [],
        ),
        'transporte',
      );
      expect(
        resolverCategoriaDeNombre(
          nombre: 'Alimentación',
          tipo: 'gasto',
          existentes: [],
        ),
        'alimentacion',
      );
      expect(
        resolverCategoriaDeNombre(
          nombre: 'Inversiones',
          tipo: 'ingreso',
          existentes: [],
        ),
        'inversiones',
      );
    });

    test('no permite crear una categoría duplicada de "Otro"', () {
      expect(
        resolverCategoriaDeNombre(
          nombre: 'otro',
          tipo: 'gasto',
          existentes: [],
        ),
        'otro',
      );
    });

    test('reutiliza una personalizada existente sin importar mayúsculas', () {
      expect(
        resolverCategoriaDeNombre(
          nombre: 'mascotas',
          tipo: 'gasto',
          existentes: [gastoPersona],
        ),
        'Mascotas',
      );
    });

    test('ignora las personalizadas del otro tipo', () {
      expect(
        resolverCategoriaDeNombre(
          nombre: 'mascotas',
          tipo: 'ingreso',
          existentes: [gastoPersona],
        ),
        'mascotas',
      );
    });

    test('un nombre nuevo se devuelve recortado para que la UI lo persista',
        () {
      expect(
        resolverCategoriaDeNombre(
          nombre: '  Gimnasio  ',
          tipo: 'gasto',
          existentes: [],
        ),
        'Gimnasio',
      );
    });
  });
}