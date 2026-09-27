import 'package:intl/intl.dart';

/// El presupuesto mensual de un activo: un límite de gasto y el mes al que
/// pertenece.
///
/// A diferencia del módulo anterior, no hay "partidas" que declarar ni un
/// monto total que repartir: lo gastado se calcula siempre desde los
/// movimientos reales del activo (ver `GastosLogic.compararPresupuesto`), así
/// que el límite y la realidad nunca se desincronizan.
class PresupuestoActivo {
  final int? id;
  final int activoId;
  final int mes;
  final int anio;
  final double montoLimite;
  final DateTime fechaCreacion;

  static const String tableName = 'presupuestos_activo';

  const PresupuestoActivo({
    this.id,
    required this.activoId,
    required this.mes,
    required this.anio,
    required this.montoLimite,
    required this.fechaCreacion,
  });

  /// Un activo no puede tener dos presupuestos del mismo mes.
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activo_id INTEGER NOT NULL,
      mes INTEGER NOT NULL,
      anio INTEGER NOT NULL,
      monto_limite REAL NOT NULL,
      fecha_creacion TEXT NOT NULL,
      UNIQUE (activo_id, mes, anio),
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE CASCADE
    )
  ''';

  PresupuestoActivo copyWith({
    int? id,
    int? activoId,
    int? mes,
    int? anio,
    double? montoLimite,
    DateTime? fechaCreacion,
  }) {
    return PresupuestoActivo(
      id: id ?? this.id,
      activoId: activoId ?? this.activoId,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
      montoLimite: montoLimite ?? this.montoLimite,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'activo_id': activoId,
      'mes': mes,
      'anio': anio,
      'monto_limite': montoLimite,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory PresupuestoActivo.fromMap(Map<String, dynamic> map) {
    return PresupuestoActivo(
      id: map['id'] as int?,
      activoId: map['activo_id'] as int,
      mes: map['mes'] as int,
      anio: map['anio'] as int,
      montoLimite: (map['monto_limite'] as num).toDouble(),
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}
