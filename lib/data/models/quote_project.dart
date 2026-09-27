import 'package:intl/intl.dart';

class QuoteProject {
  final int? id;
  final String titulo;
  final String objetivo;
  final DateTime fechaCreacion;

  const QuoteProject({
    this.id,
    required this.titulo,
    required this.objetivo,
    required this.fechaCreacion,
  });

  static const String tableName = 'proyectos_cotizacion';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      titulo TEXT NOT NULL,
      objetivo TEXT NOT NULL,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  QuoteProject copyWith({
    int? id,
    String? titulo,
    String? objetivo,
    DateTime? fechaCreacion,
  }) {
    return QuoteProject(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      objetivo: objetivo ?? this.objetivo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'titulo': titulo,
      'objetivo': objetivo,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory QuoteProject.fromMap(Map<String, dynamic> map) {
    return QuoteProject(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      objetivo: map['objetivo'] as String,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}