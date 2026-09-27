import 'package:intl/intl.dart';

/// Plantilla de un gasto que se repite cada mes: internet, luz, arriendo,
/// suscripciones.
///
/// No es un registro de dinero sino la instrucción "esto lo pago todos los
/// meses". Los pagos de cada mes se materializan en [PagoGastoFijo] y, al
/// confirmarlos, generan el movimiento real que alimenta el presupuesto del
/// activo.
class GastoFijo {
  final int? id;
  final String nombre;
  final String categoria;
  final double montoEstimado;

  /// Día del mes en que se paga (1-31). En meses más cortos se ajusta al
  /// último día de ese mes.
  final int diaPago;

  /// Activo (cuenta) del que sale el dinero. Un gasto fijo sin activo no se
  /// puede confirmar: la pantalla de pago exige elegir uno.
  final int? activoId;

  /// true cuando el precio cambia cada mes (la luz, por ejemplo): el importe
  /// que se precarga al pagar es una estimación y el usuario lo corrige.
  /// false cuando el precio es fijo (el internet): un toque lo registra.
  final bool montoVariable;

  /// false cuando la plantilla está pausada: deja de generar pagos nuevos sin
  /// borrar el historial ya pagado.
  final bool habilitado;
  final String periodicidad;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String? notas;
  final DateTime fechaCreacion;

  static const String tableName = 'gastos_fijos';

  /// Periodicidades soportadas. Hoy solo mensual; el campo existe para que
  /// sumar quincenal o semanal no obligue a cambiar el esquema.
  static const String periodicidadMensual = 'mensual';
  static const List<String> periodicidadesValidas = [periodicidadMensual];

  const GastoFijo({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.montoEstimado,
    this.diaPago = 1,
    this.activoId,
    this.montoVariable = false,
    this.habilitado = true,
    this.periodicidad = periodicidadMensual,
    required this.fechaInicio,
    this.fechaFin,
    this.notas,
    required this.fechaCreacion,
  });

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre TEXT NOT NULL,
      categoria TEXT NOT NULL,
      monto_estimado REAL NOT NULL DEFAULT 0,
      dia_pago INTEGER NOT NULL DEFAULT 1,
      activo_id INTEGER,
      monto_variable INTEGER NOT NULL DEFAULT 0,
      habilitado INTEGER NOT NULL DEFAULT 1,
      periodicidad TEXT NOT NULL DEFAULT '$periodicidadMensual',
      fecha_inicio TEXT NOT NULL,
      fecha_fin TEXT,
      notas TEXT,
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  /// Si la plantilla aplica en el mes/año dados, según su ventana de
  /// vigencia ([fechaInicio] / [fechaFin]).
  bool aplicaEn(int mes, int anio) {
    if (!habilitado) return false;
    final periodo = anio * 100 + mes;
    final inicio = fechaInicio.year * 100 + fechaInicio.month;
    if (periodo < inicio) return false;
    final fin = fechaFin;
    if (fin != null) {
      final periodoFin = fin.year * 100 + fin.month;
      if (periodo > periodoFin) return false;
    }
    return true;
  }

  /// El día del pago dentro de un mes concreto, ajustado al último día cuando
  /// el mes es más corto que [diaPago] (p. ej. el 31 en febrero).
  DateTime fechaDePagoEn(int mes, int anio) {
    final ultimoDia = DateTime(anio, mes + 1, 0).day;
    final dia = diaPago > ultimoDia ? ultimoDia : diaPago;
    return DateTime(anio, mes, dia);
  }

  GastoFijo copyWith({
    int? id,
    String? nombre,
    String? categoria,
    double? montoEstimado,
    int? diaPago,
    int? activoId,
    bool? montoVariable,
    bool? habilitado,
    String? periodicidad,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? notas,
    DateTime? fechaCreacion,
  }) {
    return GastoFijo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      montoEstimado: montoEstimado ?? this.montoEstimado,
      diaPago: diaPago ?? this.diaPago,
      activoId: activoId ?? this.activoId,
      montoVariable: montoVariable ?? this.montoVariable,
      habilitado: habilitado ?? this.habilitado,
      periodicidad: periodicidad ?? this.periodicidad,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      notas: notas ?? this.notas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'monto_estimado': montoEstimado,
      'dia_pago': diaPago,
      'activo_id': activoId,
      'monto_variable': montoVariable ? 1 : 0,
      'habilitado': habilitado ? 1 : 0,
      'periodicidad': periodicidad,
      'fecha_inicio': DateFormat('yyyy-MM-dd').format(fechaInicio),
      'fecha_fin':
          fechaFin != null ? DateFormat('yyyy-MM-dd').format(fechaFin!) : null,
      'notas': notas,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory GastoFijo.fromMap(Map<String, dynamic> map) {
    return GastoFijo(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      categoria: map['categoria'] as String,
      montoEstimado: (map['monto_estimado'] as num?)?.toDouble() ?? 0,
      diaPago: (map['dia_pago'] as num?)?.toInt() ?? 1,
      activoId: map['activo_id'] as int?,
      montoVariable: ((map['monto_variable'] as num?)?.toInt() ?? 0) == 1,
      habilitado: ((map['habilitado'] as num?)?.toInt() ?? 1) == 1,
      periodicidad: map['periodicidad'] as String? ?? periodicidadMensual,
      fechaInicio: DateFormat('yyyy-MM-dd').parse(map['fecha_inicio'] as String),
      fechaFin: map['fecha_fin'] != null
          ? DateFormat('yyyy-MM-dd').parse(map['fecha_fin'] as String)
          : null,
      notas: map['notas'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}
