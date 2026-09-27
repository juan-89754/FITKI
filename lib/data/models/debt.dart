import 'package:intl/intl.dart';

class Debt {
  final int? id;
  final String nombreAcreedor;
  final double montoPendiente;

  /// Monto original de la deuda (del cual se deriva el progreso de pago).
  /// `null` en instalaciones antiguas: se usa [montoPendiente] como base.
  final double? montoInicial;
  final String? plazo;
  final double? valorCuota;
  final double? tasaInteres;
  final DateTime? fechaProximoPago;
  final String? observaciones;
  final DateTime fechaCreacion;

  const Debt({
    this.id,
    required this.nombreAcreedor,
    required this.montoPendiente,
    this.montoInicial,
    this.plazo,
    this.valorCuota,
    this.tasaInteres,
    this.fechaProximoPago,
    this.observaciones,
    required this.fechaCreacion,
  });

  static const String tableName = 'deudas';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre_acreedor TEXT NOT NULL,
      monto_pendiente REAL NOT NULL,
      monto_inicial REAL,
      plazo TEXT,
      valor_cuota REAL,
      tasa_interes REAL,
      fecha_proximo_pago TEXT,
      observaciones TEXT,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  static const String columnaMontoInicialSQL =
      'ALTER TABLE $tableName ADD COLUMN monto_inicial REAL';

  Debt copyWith({
    int? id,
    String? nombreAcreedor,
    double? montoPendiente,
    double? montoInicial,
    String? plazo,
    double? valorCuota,
    double? tasaInteres,
    DateTime? fechaProximoPago,
    String? observaciones,
    DateTime? fechaCreacion,
  }) {
    return Debt(
      id: id ?? this.id,
      nombreAcreedor: nombreAcreedor ?? this.nombreAcreedor,
      montoPendiente: montoPendiente ?? this.montoPendiente,
      montoInicial: montoInicial ?? this.montoInicial,
      plazo: plazo ?? this.plazo,
      valorCuota: valorCuota ?? this.valorCuota,
      tasaInteres: tasaInteres ?? this.tasaInteres,
      fechaProximoPago: fechaProximoPago ?? this.fechaProximoPago,
      observaciones: observaciones ?? this.observaciones,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre_acreedor': nombreAcreedor,
      'monto_pendiente': montoPendiente,
      'monto_inicial': montoInicial,
      'plazo': plazo,
      'valor_cuota': valorCuota,
      'tasa_interes': tasaInteres,
      'fecha_proximo_pago': fechaProximoPago != null
          ? DateFormat('yyyy-MM-dd').format(fechaProximoPago!)
          : null,
      'observaciones': observaciones,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] as int?,
      nombreAcreedor: map['nombre_acreedor'] as String,
      montoPendiente: (map['monto_pendiente'] as num).toDouble(),
      montoInicial: map['monto_inicial'] != null
          ? (map['monto_inicial'] as num).toDouble()
          : null,
      plazo: map['plazo'] as String?,
      valorCuota: map['valor_cuota'] != null
          ? (map['valor_cuota'] as num).toDouble()
          : null,
      tasaInteres: map['tasa_interes'] != null
          ? (map['tasa_interes'] as num).toDouble()
          : null,
      fechaProximoPago: map['fecha_proximo_pago'] != null
          ? DateFormat('yyyy-MM-dd').parse(map['fecha_proximo_pago'] as String)
          : null,
      observaciones: map['observaciones'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}