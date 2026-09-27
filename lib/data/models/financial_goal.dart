import 'package:intl/intl.dart';

class FinancialGoal {
  final int? id;
  final String nombre;
  final double? montoObjetivo;
  final String finalidad;
  final DateTime? fechaEstimada;
  final String? comentarios;
  final double montoAhorrado;
  final DateTime fechaCreacion;

  const FinancialGoal({
    this.id,
    required this.nombre,
    this.montoObjetivo,
    required this.finalidad,
    this.fechaEstimada,
    this.comentarios,
    required this.montoAhorrado,
    required this.fechaCreacion,
  });

  static const String tableName = 'metas_financieras';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      monto_objetivo REAL,
      finalidad TEXT NOT NULL,
      fecha_estimada TEXT,
      comentarios TEXT,
      monto_ahorrado REAL NOT NULL DEFAULT 0,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  FinancialGoal copyWith({
    int? id,
    String? nombre,
    double? montoObjetivo,
    String? finalidad,
    DateTime? fechaEstimada,
    String? comentarios,
    double? montoAhorrado,
    DateTime? fechaCreacion,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      montoObjetivo: montoObjetivo ?? this.montoObjetivo,
      finalidad: finalidad ?? this.finalidad,
      fechaEstimada: fechaEstimada ?? this.fechaEstimada,
      comentarios: comentarios ?? this.comentarios,
      montoAhorrado: montoAhorrado ?? this.montoAhorrado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'monto_objetivo': montoObjetivo,
      'finalidad': finalidad,
      'fecha_estimada': fechaEstimada != null
          ? DateFormat('yyyy-MM-dd').format(fechaEstimada!)
          : null,
      'comentarios': comentarios,
      'monto_ahorrado': montoAhorrado,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory FinancialGoal.fromMap(Map<String, dynamic> map) {
    return FinancialGoal(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      montoObjetivo: map['monto_objetivo'] != null
          ? (map['monto_objetivo'] as num).toDouble()
          : null,
      finalidad: map['finalidad'] as String,
      fechaEstimada: map['fecha_estimada'] != null
          ? DateFormat('yyyy-MM-dd').parse(map['fecha_estimada'] as String)
          : null,
      comentarios: map['comentarios'] as String?,
      montoAhorrado: (map['monto_ahorrado'] as num).toDouble(),
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}