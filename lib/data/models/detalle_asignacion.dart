/// Un bolsillo de un plan de asignación: cuánto del plan se destina a una
/// categoría concreta.
///
/// A diferencia del esquema de sobres clásico, aquí NO se guarda cuánto se ha
/// gastado ([montoAsignado] es solo el límite/meta). Lo gastado se deriva en
/// tiempo real sumando los movimientos vinculados a este detalle (ver
/// `AsignacionLogic`), así el plan y la realidad nunca se desincronizan.
class DetalleAsignacion {
  final int? id;

  /// Plan al que pertenece el bolsillo. Al borrar el plan se borran sus
  /// detalles (cascada manual, las FK no están habilitadas).
  final int? planId;

  /// Slug de categoría fija o nombre de categoría personalizada. Es el mismo
  /// valor que llevan los movimientos, lo que permite resolver el vínculo
  /// automático por categoría.
  final String categoria;

  /// Monto asignado a la categoría dentro del plan.
  final double montoAsignado;

  static const String tableName = 'detalles_asignacion';

  const DetalleAsignacion({
    this.id,
    this.planId,
    required this.categoria,
    required this.montoAsignado,
  });

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_id INTEGER NOT NULL,
      categoria TEXT NOT NULL,
      monto_asignado REAL NOT NULL DEFAULT 0,
      FOREIGN KEY (plan_id) REFERENCES planes_asignacion(id) ON DELETE CASCADE
    )
  ''';

  DetalleAsignacion copyWith({
    int? id,
    int? planId,
    String? categoria,
    double? montoAsignado,
  }) {
    return DetalleAsignacion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      categoria: categoria ?? this.categoria,
      montoAsignado: montoAsignado ?? this.montoAsignado,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plan_id': planId,
      'categoria': categoria,
      'monto_asignado': montoAsignado,
    };
  }

  factory DetalleAsignacion.fromMap(Map<String, dynamic> map) {
    return DetalleAsignacion(
      id: map['id'] as int?,
      planId: map['plan_id'] as int?,
      categoria: map['categoria'] as String,
      montoAsignado: (map['monto_asignado'] as num?)?.toDouble() ?? 0,
    );
  }
}
