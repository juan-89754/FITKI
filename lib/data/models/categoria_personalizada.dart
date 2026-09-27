/// Categoría de movimientos creada por el usuario.
///
/// `icono` guarda el nombre del ícono de Material a usar (p. ej.
/// 'restaurant_rounded' o 'Icons.home_rounded'); la capa de UI lo resuelve a
/// un [IconData]. `tipo` indica en qué dropdown aparece la categoría:
/// 'gasto' o 'ingreso'.
class CategoriaPersonalizada {
  final int? id;
  final String nombre;
  final String icono;
  final String tipo;

  static const String tableName = 'categorias_personalizadas';

  static const List<String> tiposValidos = ['gasto', 'ingreso'];

  const CategoriaPersonalizada({
    this.id,
    required this.nombre,
    required this.icono,
    required this.tipo,
  });

  // MANTENER EN SINCRONÍA CON _onUpgrade de DbHelper: el SQL de la migración
  // debe usar esta misma constante para no divergir del esquema inicial.
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      icono TEXT NOT NULL,
      tipo TEXT NOT NULL CHECK (tipo IN ('gasto', 'ingreso'))
    )
  ''';

  CategoriaPersonalizada copyWith({
    int? id,
    String? nombre,
    String? icono,
    String? tipo,
  }) {
    return CategoriaPersonalizada(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      icono: icono ?? this.icono,
      tipo: tipo ?? this.tipo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'icono': icono,
      'tipo': tipo,
    };
  }

  factory CategoriaPersonalizada.fromMap(Map<String, dynamic> map) {
    return CategoriaPersonalizada(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      icono: map['icono'] as String,
      tipo: map['tipo'] as String,
    );
  }
}