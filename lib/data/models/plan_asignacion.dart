import 'package:intl/intl.dart';

/// Un plan de asignación: un monto total repartido entre categorías (bolsillos)
/// dentro de un activo concreto. Sustituye al presupuesto mensual rígido.
///
/// No tiene período: dura lo que el usuario decida (una quincena, un viaje,
/// indefinido). Tampoco caduca solo; permanece activo hasta que se archive.
///
/// Un plan puede estar en dos estados de fondos:
/// - Real ([esProyectado] `false`): el dinero ya existe en el activo, así que
///   sus asignaciones cuentan como saldo comprometido.
/// - Proyectado ([esProyectado] `true`): planeación previa a que entre el
///   dinero ("voto de inicio"); no compromete saldo hasta activarse.
class PlanAsignacion {
  final int? id;

  /// Activo (cuenta/caja) sobre el que se asignan los fondos. Puede quedar en
  /// null si se borra la cuenta; el plan y su historial no se pierden.
  final int? activoId;
  final String nombre;

  /// Monto total a repartir entre los bolsillos del plan.
  final double montoTotalObjetivo;

  /// true cuando el dinero aún no existe en el activo (plan proyectado).
  final bool esProyectado;

  /// true cuando el usuario liquidó/archivó el plan. Sigue en el historial pero
  /// deja de contar para el saldo comprometido.
  final bool archivado;

  final DateTime fechaCreacion;
  final DateTime? fechaCierre;

  static const String tableName = 'planes_asignacion';

  const PlanAsignacion({
    this.id,
    this.activoId,
    required this.nombre,
    required this.montoTotalObjetivo,
    this.esProyectado = false,
    this.archivado = false,
    required this.fechaCreacion,
    this.fechaCierre,
  });

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activo_id INTEGER,
      nombre TEXT NOT NULL,
      monto_total_objetivo REAL NOT NULL DEFAULT 0,
      es_proyectado INTEGER NOT NULL DEFAULT 0,
      archivado INTEGER NOT NULL DEFAULT 0,
      fecha_creacion TEXT NOT NULL,
      fecha_cierre TEXT,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  bool get activo => !archivado;

  PlanAsignacion copyWith({
    int? id,
    int? activoId,
    String? nombre,
    double? montoTotalObjetivo,
    bool? esProyectado,
    bool? archivado,
    DateTime? fechaCreacion,
    DateTime? fechaCierre,
    bool fechaCierreCleared = false,
  }) {
    return PlanAsignacion(
      id: id ?? this.id,
      activoId: activoId ?? this.activoId,
      nombre: nombre ?? this.nombre,
      montoTotalObjetivo: montoTotalObjetivo ?? this.montoTotalObjetivo,
      esProyectado: esProyectado ?? this.esProyectado,
      archivado: archivado ?? this.archivado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaCierre: fechaCierreCleared ? null : (fechaCierre ?? this.fechaCierre),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'activo_id': activoId,
      'nombre': nombre,
      'monto_total_objetivo': montoTotalObjetivo,
      'es_proyectado': esProyectado ? 1 : 0,
      'archivado': archivado ? 1 : 0,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
      'fecha_cierre': fechaCierre != null
          ? DateFormat('yyyy-MM-dd').format(fechaCierre!)
          : null,
    };
  }

  factory PlanAsignacion.fromMap(Map<String, dynamic> map) {
    return PlanAsignacion(
      id: map['id'] as int?,
      activoId: map['activo_id'] as int?,
      nombre: map['nombre'] as String,
      montoTotalObjetivo: (map['monto_total_objetivo'] as num?)?.toDouble() ?? 0,
      esProyectado: ((map['es_proyectado'] as num?)?.toInt() ?? 0) == 1,
      archivado: ((map['archivado'] as num?)?.toInt() ?? 0) == 1,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
      fechaCierre: map['fecha_cierre'] != null
          ? DateFormat('yyyy-MM-dd').parse(map['fecha_cierre'] as String)
          : null,
    );
  }
}
