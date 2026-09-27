import 'package:intl/intl.dart';

class Asset {
  final int? id;
  final String nombre;
  final String tipo;
  final double montoDisponible;
  final String moneda;
  final String? descripcion;
  final DateTime fechaCreacion;

  static const tiposValidos = [
    'cuenta_bancaria',
    'billetera_digital',
    'efectivo',
    'otro',
  ];

  const Asset({
    this.id,
    required this.nombre,
    required this.tipo,
    required this.montoDisponible,
    required this.moneda,
    this.descripcion,
    required this.fechaCreacion,
  });

  static const String tableName = 'activos';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      tipo TEXT NOT NULL,
      monto_disponible REAL NOT NULL DEFAULT 0,
      moneda TEXT NOT NULL DEFAULT 'COP',
      descripcion TEXT,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  Asset copyWith({
    int? id,
    String? nombre,
    String? tipo,
    double? montoDisponible,
    String? moneda,
    String? descripcion,
    DateTime? fechaCreacion,
  }) {
    return Asset(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      montoDisponible: montoDisponible ?? this.montoDisponible,
      moneda: moneda ?? this.moneda,
      descripcion: descripcion ?? this.descripcion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'tipo': tipo,
      'monto_disponible': montoDisponible,
      'moneda': moneda,
      'descripcion': descripcion,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      tipo: map['tipo'] as String,
      montoDisponible: (map['monto_disponible'] as num).toDouble(),
      moneda: map['moneda'] as String,
      descripcion: map['descripcion'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['fecha_creacion'] as String),
    );
  }
}