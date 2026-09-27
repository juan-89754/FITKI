import 'package:intl/intl.dart';

class Quote {
  final int? id;
  final int proyectoId;
  final String titulo;
  final String? notas;
  final DateTime fechaCreacion;

  const Quote({
    this.id,
    required this.proyectoId,
    required this.titulo,
    this.notas,
    required this.fechaCreacion,
  });

  static const String tableName = 'cotizaciones';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proyecto_id INTEGER NOT NULL,
      titulo TEXT NOT NULL,
      notas TEXT,
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (proyecto_id) REFERENCES proyectos_cotizacion(id) ON DELETE CASCADE
    )
  ''';

  Quote copyWith({
    int? id,
    int? proyectoId,
    String? titulo,
    String? notas,
    DateTime? fechaCreacion,
  }) {
    return Quote(
      id: id ?? this.id,
      proyectoId: proyectoId ?? this.proyectoId,
      titulo: titulo ?? this.titulo,
      notas: notas ?? this.notas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'proyecto_id': proyectoId,
      'titulo': titulo,
      'notas': notas,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] as int?,
      proyectoId: map['proyecto_id'] as int,
      titulo: map['titulo'] as String,
      notas: map['notas'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}