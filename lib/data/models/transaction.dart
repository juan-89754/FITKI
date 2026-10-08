import 'package:intl/intl.dart';

class Transaction {
  final int? id;
  final String tipo;
  final double monto;
  final String categoria;
  final DateTime fecha;
  final int? activoId;

  /// Préstamo al que pertenece este movimiento, si alguno.
  ///
  /// Es lo que permite saber qué movimientos nacieron de un préstamo para
  /// borrarlos junto con él y devolver su dinero al activo. Los movimientos
  /// normales lo dejan en null.
  final int? prestamoId;

  final String? nota;
  final DateTime fechaCreacion;

  /// Ruta/localización del comprobante/factura asociado al movimiento.
  final String? comprobantePath;

  /// Nombre del archivo original del comprobante.
  final String? comprobanteNombre;

  /// Tipo MIME del comprobante (p. ej. image/jpeg, image/png, application/pdf).
  final String? comprobanteMimeType;

  /// Tamaño del archivo en bytes.
  final int? comprobanteSizeBytes;

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
    this.prestamoId,
    this.nota,
    required this.fechaCreacion,
    this.comprobantePath,
    this.comprobanteNombre,
    this.comprobanteMimeType,
    this.comprobanteSizeBytes,
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
      prestamo_id INTEGER,
      nota TEXT,
      fecha_creacion TEXT NOT NULL,
      comprobante_path TEXT,
      comprobante_nombre TEXT,
      comprobante_mime_type TEXT,
      comprobante_size_bytes INTEGER,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL,
      FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
    )
  ''';

  Transaction copyWith({
    int? id,
    String? tipo,
    double? monto,
    String? categoria,
    DateTime? fecha,
    int? activoId,
    int? prestamoId,
    String? nota,
    DateTime? fechaCreacion,
    String? comprobantePath,
    String? comprobanteNombre,
    String? comprobanteMimeType,
    int? comprobanteSizeBytes,
    bool comprobantePathCleared = false,
    bool comprobanteNombreCleared = false,
    bool comprobanteMimeTypeCleared = false,
    bool comprobanteSizeBytesCleared = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      categoria: categoria ?? this.categoria,
      fecha: fecha ?? this.fecha,
      activoId: activoId ?? this.activoId,
      prestamoId: prestamoId ?? this.prestamoId,
      nota: nota ?? this.nota,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      comprobantePath: comprobantePathCleared
          ? null
          : (comprobantePath ?? this.comprobantePath),
      comprobanteNombre: comprobanteNombreCleared
          ? null
          : (comprobanteNombre ?? this.comprobanteNombre),
      comprobanteMimeType: comprobanteMimeTypeCleared
          ? null
          : (comprobanteMimeType ?? this.comprobanteMimeType),
      comprobanteSizeBytes: comprobanteSizeBytesCleared
          ? null
          : (comprobanteSizeBytes ?? this.comprobanteSizeBytes),
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
      'prestamo_id': prestamoId,
      'nota': nota,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
      'comprobante_path': comprobantePath,
      'comprobante_nombre': comprobanteNombre,
      'comprobante_mime_type': comprobanteMimeType,
      'comprobante_size_bytes': comprobanteSizeBytes,
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
      prestamoId: map['prestamo_id'] as int?,
      nota: map['nota'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['fecha_creacion'] as String),
      comprobantePath: map['comprobante_path'] as String?,
      comprobanteNombre: map['comprobante_nombre'] as String?,
      comprobanteMimeType: map['comprobante_mime_type'] as String?,
      comprobanteSizeBytes: map['comprobante_size_bytes'] as int?,
    );
  }
}