import 'package:intl/intl.dart';

/// Un [GastoFijo] materializado en un mes concreto: "en marzo tocaba pagar
/// internet".
///
/// Nace pendiente ([montoPagado] null). Al pagarse guarda el importe real y
/// el movimiento que generó, de modo que el presupuesto del activo y el
/// historial de precios se alimentan del mismo dato.
class PagoGastoFijo {
  final int? id;
  final int gastoFijoId;
  final int mes;
  final int anio;

  /// Copia del estimado de la plantilla al generar el pago, para que un
  /// cambio de precio en la plantilla no reescriba lo que ya se facturó.
  final double montoEstimado;

  /// Importe efectivamente pagado; null mientras siga pendiente.
  final double? montoPagado;
  final DateTime? fechaPago;
  final int? movimientoId;
  final DateTime fechaCreacion;

  static const String tableName = 'pagos_gastos_fijos';

  const PagoGastoFijo({
    this.id,
    required this.gastoFijoId,
    required this.mes,
    required this.anio,
    this.montoEstimado = 0,
    this.montoPagado,
    this.fechaPago,
    this.movimientoId,
    required this.fechaCreacion,
  });

  /// La restricción UNIQUE (gasto_fijo_id, mes, anio) es lo que hace segura la
  /// generación automática: un mismo gasto fijo nunca produce dos pagos del
  /// mismo mes, aunque la app se abra cuántas veces quiera.
  ///
  /// La FK hacia `gastos_fijos` va SIN cascada a propósito: borrar una
  /// plantilla no debe borrar lo que ya se pagó. Los pagos quedan como
  /// registro huérfano (las lecturas los ignoran cuando no hallan su
  /// plantilla) y el historial que importa sigue en `movimientos`, que es
  /// intocable.
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      gasto_fijo_id INTEGER NOT NULL,
      mes INTEGER NOT NULL,
      anio INTEGER NOT NULL,
      monto_estimado REAL NOT NULL DEFAULT 0,
      monto_pagado REAL,
      fecha_pago TEXT,
      movimiento_id INTEGER,
      fecha_creacion TEXT NOT NULL,
      UNIQUE (gasto_fijo_id, mes, anio),
      FOREIGN KEY (gasto_fijo_id) REFERENCES gastos_fijos(id),
      FOREIGN KEY (movimiento_id) REFERENCES movimientos(id) ON DELETE SET NULL
    )
  ''';

  bool get pagado => montoPagado != null;

  /// Cuánto se desvió el pago real del estimado. Positivo = costó más.
  double get diferencia => (montoPagado ?? 0) - montoEstimado;

  double get porcentajeDesvio {
    if (montoEstimado <= 0) return 0;
    return (diferencia / montoEstimado) * 100;
  }

  PagoGastoFijo copyWith({
    int? id,
    int? gastoFijoId,
    int? mes,
    int? anio,
    double? montoEstimado,
    double? montoPagado,
    DateTime? fechaPago,
    int? movimientoId,
    DateTime? fechaCreacion,
  }) {
    return PagoGastoFijo(
      id: id ?? this.id,
      gastoFijoId: gastoFijoId ?? this.gastoFijoId,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
      montoEstimado: montoEstimado ?? this.montoEstimado,
      montoPagado: montoPagado ?? this.montoPagado,
      fechaPago: fechaPago ?? this.fechaPago,
      movimientoId: movimientoId ?? this.movimientoId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'gasto_fijo_id': gastoFijoId,
      'mes': mes,
      'anio': anio,
      'monto_estimado': montoEstimado,
      'monto_pagado': montoPagado,
      'fecha_pago':
          fechaPago != null ? DateFormat('yyyy-MM-dd').format(fechaPago!) : null,
      'movimiento_id': movimientoId,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory PagoGastoFijo.fromMap(Map<String, dynamic> map) {
    return PagoGastoFijo(
      id: map['id'] as int?,
      gastoFijoId: map['gasto_fijo_id'] as int,
      mes: map['mes'] as int,
      anio: map['anio'] as int,
      montoEstimado: (map['monto_estimado'] as num?)?.toDouble() ?? 0,
      montoPagado: (map['monto_pagado'] as num?)?.toDouble(),
      fechaPago: map['fecha_pago'] != null
          ? DateFormat('yyyy-MM-dd').parse(map['fecha_pago'] as String)
          : null,
      movimientoId: map['movimiento_id'] as int?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}
