import 'package:intl/intl.dart';

/// El presupuesto mensual de una categoría: cuánto está dispuesto el usuario a
/// gastar en alimentación, transporte, ocio, etc. durante un mes concreto.
///
/// A diferencia del viejo límite por cuenta, este plan sí es accionable: se
/// compara contra los movimientos reales de esa categoría (ver
/// `GastosLogic.compararPresupuestoCategoria`), así que dice exactamente en qué
/// se está pasando y en qué no. No hay partidas ni un total que repartir: lo
/// gastado sale siempre del historial, y el plan y la realidad nunca se
/// desincronizan.
class PresupuestoCategoria {
  final int? id;

  /// Slug de una categoría fija (p. ej. 'alimentacion') o el nombre guardado de
  /// una categoría personalizada. Es el mismo valor que llevan los movimientos,
  /// que es lo que permite sumar lo gastado sin ambigüedad.
  final String categoria;
  final int mes;
  final int anio;
  final double montoLimite;
  final DateTime fechaCreacion;

  static const String tableName = 'presupuestos_categoria';

  const PresupuestoCategoria({
    this.id,
    required this.categoria,
    required this.mes,
    required this.anio,
    required this.montoLimite,
    required this.fechaCreacion,
  });

  /// Una categoría no puede tener dos presupuestos del mismo mes.
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      categoria TEXT NOT NULL,
      mes INTEGER NOT NULL,
      anio INTEGER NOT NULL,
      monto_limite REAL NOT NULL,
      fecha_creacion TEXT NOT NULL,
      UNIQUE (categoria, mes, anio)
    )
  ''';

  PresupuestoCategoria copyWith({
    int? id,
    String? categoria,
    int? mes,
    int? anio,
    double? montoLimite,
    DateTime? fechaCreacion,
  }) {
    return PresupuestoCategoria(
      id: id ?? this.id,
      categoria: categoria ?? this.categoria,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
      montoLimite: montoLimite ?? this.montoLimite,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'categoria': categoria,
      'mes': mes,
      'anio': anio,
      'monto_limite': montoLimite,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory PresupuestoCategoria.fromMap(Map<String, dynamic> map) {
    return PresupuestoCategoria(
      id: map['id'] as int?,
      categoria: map['categoria'] as String,
      mes: map['mes'] as int,
      anio: map['anio'] as int,
      montoLimite: (map['monto_limite'] as num).toDouble(),
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}
