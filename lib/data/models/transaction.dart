import 'package:intl/intl.dart';

class Transaction {
  final int? id;
  final String tipo;
  final double monto;
  final String categoria;
  final DateTime fecha;
  final int? activoId;
  final String? nota;
  final DateTime fechaCreacion;

  static const String tipoIngreso = 'ingreso';
  static const String tipoGasto = 'gasto';
  static const tiposValidos = [tipoIngreso, tipoGasto];

  const Transaction({
    this.id,
    required this.tipo,
    required this.monto,
    required this.categoria,
    required this.fecha,
    this.activoId,
    this.nota,
    required this.fechaCreacion,
  });

  static const String tableName = 'movimientos';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo TEXT NOT NULL,
      monto REAL NOT NULL,
      categoria TEXT NOT NULL,
      fecha TEXT NOT NULL,
      activo_id INTEGER,
      nota TEXT,
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  Transaction copyWith({
    int? id,
    String? tipo,
    double? monto,
    String? categoria,
    DateTime? fecha,
    int? activoId,
    String? nota,
    DateTime? fechaCreacion,
  }) {
    return Transaction(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      categoria: categoria ?? this.categoria,
      fecha: fecha ?? this.fecha,
      activoId: activoId ?? this.activoId,
      nota: nota ?? this.nota,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tipo': tipo,
      'monto': monto,
      'categoria': categoria,
      'fecha': DateFormat('yyyy-MM-dd').format(fecha),
      'activo_id': activoId,
      'nota': nota,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      monto: (map['monto'] as num).toDouble(),
      categoria: map['categoria'] as String,
      fecha: DateFormat('yyyy-MM-dd').parse(map['fecha'] as String),
      activoId: map['activo_id'] as int?,
      nota: map['nota'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['fecha_creacion'] as String),
    );
  }
}