import 'package:intl/intl.dart';

/// Un aporte o un retiro de una meta financiera: "el 12 de marzo aparté
/// $200.000 para el viaje" o "el 3 de mayo saqué $50.000 de la meta".
///
/// **Aportar a una meta no mueve dinero de la cuenta.** El dinero sigue dentro
/// del activo: lo que cambia es que pasa de "disponible" a "reservado en esta
/// meta". Por eso un aporte NO escribe un movimiento de gasto ni toca
/// `activos.monto_disponible` (el Saldo Total); lo que hace es bajar el Saldo
/// Disponible de esa cuenta. Retirar hace exactamente lo contrario.
///
/// Esa es la razón de que este registro viva en su propia tabla y no en
/// `movimientos`: un movimiento mueve el saldo real del activo, y un aporte a
/// una meta no mueve saldo real, solo disponibilidad.
///
/// El saldo de la meta **nunca se escribe a mano**: se deriva de la suma de
/// estos registros (Σ aportes − Σ retiros), de modo que no puede quedar
/// descuadrado con su propio historial.
class AbonoMeta {
  final int? id;
  final int metaId;

  /// [tipoAporte] suma al saldo de la meta, [tipoRetiro] lo resta.
  final String tipo;
  final double monto;
  final DateTime fecha;

  /// Activo (cuenta) de la que salió el dinero en un aporte, o al que vuelve en
  /// un retiro. La FK va SIN cascada: si la cuenta se borra, el registro
  /// conserva su historia y queda sin cuenta.
  final int? activoId;

  /// Sin uso desde que el aporte dejó de crear un movimiento de gasto.
  ///
  /// La columna se conserva porque ya está en las bases creadas por la
  /// migración v10 y las claves foráneas no están habilitadas: no se puede
  /// quitar sin reescribir la tabla y perder el historial.
  final int? movimientoId;

  final String? nota;
  final DateTime fechaCreacion;

  static const String tableName = 'abonos_metas';

  /// Nombre de la columna que distingue aporte de retiro. Vive en una constante
  /// porque la migración de la v12 la busca por nombre antes de añadirla.
  static const String columnaTipo = 'tipo';

  /// El dinero entra a la meta y sale del Saldo Disponible del activo.
  static const String tipoAporte = 'aporte';

  /// El dinero sale de la meta y vuelve al Saldo Disponible del activo.
  static const String tipoRetiro = 'retiro';

  static const List<String> tiposValidos = [tipoAporte, tipoRetiro];

  const AbonoMeta({
    this.id,
    required this.metaId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.activoId,
    this.movimientoId,
    this.nota,
    required this.fechaCreacion,
  });

  bool get esAporte => tipo == tipoAporte;

  /// El monto con su signo, para sumar de un solo vistazo.
  double get montoConSigno => esAporte ? monto : -monto;

  /// La FK hacia `metas_financieras` va CON cascada porque un aporte no tiene
  /// sentido sin su meta. La FK hacia `activos` va sin cascada para que el
  /// historial del dinero no dependa de la vida de la cuenta.
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      meta_id INTEGER NOT NULL,
      tipo TEXT NOT NULL DEFAULT 'aporte',
      monto REAL NOT NULL,
      fecha TEXT NOT NULL,
      activo_id INTEGER,
      movimiento_id INTEGER,
      nota TEXT,
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (meta_id) REFERENCES metas_financieras(id) ON DELETE CASCADE,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'meta_id': metaId,
      'tipo': tipo,
      'monto': monto,
      'fecha': DateFormat('yyyy-MM-dd').format(fecha),
      'activo_id': activoId,
      'movimiento_id': movimientoId,
      'nota': nota,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory AbonoMeta.fromMap(Map<String, dynamic> map) {
    return AbonoMeta(
      id: map['id'] as int?,
      metaId: map['meta_id'] as int,
      tipo: map['tipo'] as String? ?? tipoAporte,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateFormat('yyyy-MM-dd').parse(map['fecha'] as String),
      activoId: map['activo_id'] as int?,
      movimientoId: map['movimiento_id'] as int?,
      nota: map['nota'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}
