/// Perfil del usuario de la app: nombre y ruta local de la foto de perfil.
/// Es un registro único (solo hay un perfil), aunque se persiste en tabla
/// para mantener el mismo flujo CRUD del resto del módulo.
class Perfil {
  final int? id;
  final String nombre;
  final String? fotoPath;

  const Perfil({
    this.id,
    required this.nombre,
    this.fotoPath,
  });

  static const String tableName = 'perfil';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      foto_path TEXT
    )
  ''';

  Perfil copyWith({
    int? id,
    String? nombre,
    String? fotoPath,
  }) {
    return Perfil(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fotoPath: fotoPath ?? this.fotoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'foto_path': fotoPath,
    };
  }

  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      fotoPath: map['foto_path'] as String?,
    );
  }
}