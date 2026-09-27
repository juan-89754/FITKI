import 'package:intl/intl.dart';

class Investment {
  final int? id;
  final String tipo;
  final double montoInvertido;
  final double? tasaRendimiento;

  /// Período de la tasa de rendimiento declarada: 'anual' | 'mensual'.
  /// Sin este dato, cualquier proyección de ganancia sería ambigua.
  final String periodoTasa;
  final double? gananciaProyectada;
  final double? gananciaObtenida;
  final DateTime fecha;
  final String? notas;
  final DateTime fechaCreacion;

  static const tiposValidos = [
    'divisas',
    'bolsa',
    'mercancias',
    'eventos',
    'otro',
  ];

  static const periodosValidos = ['anual', 'mensual'];

  const Investment({
    this.id,
    required this.tipo,
    required this.montoInvertido,
    this.tasaRendimiento,
    this.periodoTasa = 'anual',
    this.gananciaProyectada,
    this.gananciaObtenida,
    required this.fecha,
    this.notas,
    required this.fechaCreacion,
  });

  static const String tableName = 'inversiones';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo TEXT NOT NULL,
      monto_invertido REAL NOT NULL,
      tasa_rendimiento REAL,
      periodo_tasa TEXT NOT NULL DEFAULT 'anual',
      ganancia_proyectada REAL,
      ganancia_obtenida REAL,
      fecha TEXT NOT NULL,
      notas TEXT,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  Investment copyWith({
    int? id,
    String? tipo,
    double? montoInvertido,
    double? tasaRendimiento,
    String? periodoTasa,
    double? gananciaProyectada,
    double? gananciaObtenida,
    DateTime? fecha,
    String? notas,
    DateTime? fechaCreacion,
  }) {
    return Investment(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      montoInvertido: montoInvertido ?? this.montoInvertido,
      tasaRendimiento: tasaRendimiento ?? this.tasaRendimiento,
      periodoTasa: periodoTasa ?? this.periodoTasa,
      gananciaProyectada: gananciaProyectada ?? this.gananciaProyectada,
      gananciaObtenida: gananciaObtenida ?? this.gananciaObtenida,
      fecha: fecha ?? this.fecha,
      notas: notas ?? this.notas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tipo': tipo,
      'monto_invertido': montoInvertido,
      'tasa_rendimiento': tasaRendimiento,
      'periodo_tasa': periodoTasa,
      'ganancia_proyectada': gananciaProyectada,
      'ganancia_obtenida': gananciaObtenida,
      'fecha': DateFormat('yyyy-MM-dd').format(fecha),
      'notas': notas,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      montoInvertido: (map['monto_invertido'] as num).toDouble(),
      tasaRendimiento: map['tasa_rendimiento'] != null
          ? (map['tasa_rendimiento'] as num).toDouble()
          : null,
      periodoTasa: map['periodo_tasa'] as String? ?? 'anual',
      gananciaProyectada: map['ganancia_proyectada'] != null
          ? (map['ganancia_proyectada'] as num).toDouble()
          : null,
      gananciaObtenida: map['ganancia_obtenida'] != null
          ? (map['ganancia_obtenida'] as num).toDouble()
          : null,
      fecha: DateFormat('yyyy-MM-dd').parse(map['fecha'] as String),
      notas: map['notas'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}