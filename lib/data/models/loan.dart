import 'package:intl/intl.dart';

class Loan {
  final int? id;
  final String nombreBeneficiario;
  final double montoPrestado;

  /// Suma acumulada de los pagos parciales registrados contra el préstamo.
  /// El estado (pendiente / pagado_parcial / pagado_total) se deriva
  /// comparando este acumulado contra [montoPrestado]; nunca al revés.
  final double montoPagado;
  final DateTime fechaPrestamo;
  final DateTime fechaPagoEsperada;

  /// Activo (cuenta) del que salió el dinero al prestar. Es obligatorio para
  /// que el préstamo mueva saldo: sin cuenta no hay contra qué descontar ni
  /// dónde devolver lo que el beneficiario reembolse.
  ///
  /// La FK va SIN cascada: si la cuenta se borra, el préstamo conserva todo su
  /// historial y queda sin cuenta, en lugar de desaparecer sus movimientos.
  final int? activoId;

  final String? condiciones;
  final String? observaciones;
  final String estado;
  final DateTime fechaCreacion;

  static const estadosValidos = [
    'pendiente',
    'pagado_parcial',
    'pagado_total',
  ];

  /// Categoría del movimiento de salida: el dinero que salió de la cuenta al
  /// prestar. Es un gasto porque el dinero efectivamente dejó el activo.
  ///
  /// No está en la lista de categorías de gasto del formulario de movimientos:
  /// solo puede nacerse desde el módulo de préstamos, porque el movimiento es
  /// lo que descuenta la cuenta y el préstamo lo que queda pendiente cobrar.
  static const String categoriaPrestamo = 'prestamo';

  /// Categoría del movimiento de entrada: lo que el beneficiario devolvió.
  /// Por la misma razón que [categoriaPrestamo], se reserva para el módulo.
  static const String categoriaReembolso = 'reembolso_prestamo';

  const Loan({
    this.id,
    required this.nombreBeneficiario,
    required this.montoPrestado,
    this.montoPagado = 0,
    this.activoId,
    this.condiciones,
    this.observaciones,
    this.estado = 'pendiente',
    required this.fechaPrestamo,
    required this.fechaPagoEsperada,
    required this.fechaCreacion,
  });

  static const String tableName = 'prestamos';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre_beneficiario TEXT NOT NULL,
      monto_prestado REAL NOT NULL,
      monto_pagado REAL NOT NULL DEFAULT 0,
      activo_id INTEGER,
      fecha_prestamo TEXT NOT NULL,
      fecha_pago_esperada TEXT NOT NULL,
      condiciones TEXT,
      observaciones TEXT,
      estado TEXT NOT NULL DEFAULT 'pendiente',
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  Loan copyWith({
    int? id,
    String? nombreBeneficiario,
    double? montoPrestado,
    double? montoPagado,
    int? activoId,
    DateTime? fechaPrestamo,
    DateTime? fechaPagoEsperada,
    String? condiciones,
    String? observaciones,
    String? estado,
    DateTime? fechaCreacion,
  }) {
    return Loan(
      id: id ?? this.id,
      nombreBeneficiario: nombreBeneficiario ?? this.nombreBeneficiario,
      montoPrestado: montoPrestado ?? this.montoPrestado,
      montoPagado: montoPagado ?? this.montoPagado,
      activoId: activoId ?? this.activoId,
      fechaPrestamo: fechaPrestamo ?? this.fechaPrestamo,
      fechaPagoEsperada: fechaPagoEsperada ?? this.fechaPagoEsperada,
      condiciones: condiciones ?? this.condiciones,
      observaciones: observaciones ?? this.observaciones,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre_beneficiario': nombreBeneficiario,
      'monto_prestado': montoPrestado,
      'monto_pagado': montoPagado,
      'activo_id': activoId,
      'fecha_prestamo': DateFormat('yyyy-MM-dd').format(fechaPrestamo),
      'fecha_pago_esperada':
          DateFormat('yyyy-MM-dd').format(fechaPagoEsperada),
      'condiciones': condiciones,
      'observaciones': observaciones,
      'estado': estado,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as int?,
      nombreBeneficiario: map['nombre_beneficiario'] as String,
      montoPrestado: (map['monto_prestado'] as num).toDouble(),
      montoPagado: (map['monto_pagado'] as num?)?.toDouble() ?? 0,
      activoId: map['activo_id'] as int?,
      fechaPrestamo:
          DateFormat('yyyy-MM-dd').parse(map['fecha_prestamo'] as String),
      fechaPagoEsperada:
          DateFormat('yyyy-MM-dd').parse(map['fecha_pago_esperada'] as String),
      condiciones: map['condiciones'] as String?,
      observaciones: map['observaciones'] as String?,
      estado: map['estado'] as String,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}