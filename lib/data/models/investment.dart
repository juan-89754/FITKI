import 'package:intl/intl.dart';

class Investment {
  final int? id;
  final String tipo;

  /// Activo (cuenta) de donde sale el dinero invertido. Es obligatorio para
  /// que la inversión reserve dinero real, igual que una meta.
  final int? activoId;

  /// Monto principal que hoy está reservado en la inversión. Se deriva del
  /// historial de aportes y retiros, nunca se escribe a mano.
  final double montoInvertido;
  final double? tasaRendimiento;

  /// Período de la tasa de rendimiento declarada: 'anual' | 'mensual'.
  /// Sin este dato, cualquier proyección de ganancia sería ambigua.
  final String periodoTasa;
  final double? gananciaProyectada;
  final double? gananciaObtenida;
  final DateTime fecha;
  final String? notas;

  /// 'activa' mientras el dinero sigue reservado; 'finalizada' cuando el
  /// usuario cierra la inversión y el resultado se registra en el historial.
  final String estado;
  final DateTime fechaCreacion;

  static const tiposValidos = [
    'divisas',
    'bolsa',
    'mercancias',
    'eventos',
    'otro',
  ];

  static const periodosValidos = ['anual', 'mensual'];

  static const estadoActiva = 'activa';
  static const estadoFinalizada = 'finalizada';
  static const estadosValidos = [estadoActiva, estadoFinalizada];

  const Investment({
    this.id,
    required this.tipo,
    this.activoId,
    required this.montoInvertido,
    this.tasaRendimiento,
    this.periodoTasa = 'anual',
    this.gananciaProyectada,
    this.gananciaObtenida,
    required this.fecha,
    this.notas,
    this.estado = estadoActiva,
    required this.fechaCreacion,
  });

  bool get estaActiva => estado == estadoActiva;

  static const String tableName = 'inversiones';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tipo TEXT NOT NULL,
      activo_id INTEGER,
      monto_invertido REAL NOT NULL,
      tasa_rendimiento REAL,
      periodo_tasa TEXT NOT NULL DEFAULT 'anual',
      ganancia_proyectada REAL,
      ganancia_obtenida REAL,
      fecha TEXT NOT NULL,
      notas TEXT,
      estado TEXT NOT NULL DEFAULT 'activa',
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  Investment copyWith({
    int? id,
    String? tipo,
    int? activoId,
    double? montoInvertido,
    double? tasaRendimiento,
    String? periodoTasa,
    double? gananciaProyectada,
    double? gananciaObtenida,
    DateTime? fecha,
    String? notas,
    String? estado,
    DateTime? fechaCreacion,
    bool activoIdCleared = false,
  }) {
    return Investment(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      activoId: activoIdCleared ? null : (activoId ?? this.activoId),
      montoInvertido: montoInvertido ?? this.montoInvertido,
      tasaRendimiento: tasaRendimiento ?? this.tasaRendimiento,
      periodoTasa: periodoTasa ?? this.periodoTasa,
      gananciaProyectada: gananciaProyectada ?? this.gananciaProyectada,
      gananciaObtenida: gananciaObtenida ?? this.gananciaObtenida,
      fecha: fecha ?? this.fecha,
      notas: notas ?? this.notas,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tipo': tipo,
      'activo_id': activoId,
      'monto_invertido': montoInvertido,
      'tasa_rendimiento': tasaRendimiento,
      'periodo_tasa': periodoTasa,
      'ganancia_proyectada': gananciaProyectada,
      'ganancia_obtenida': gananciaObtenida,
      'fecha': DateFormat('yyyy-MM-dd').format(fecha),
      'notas': notas,
      'estado': estado,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      activoId: map['activo_id'] as int?,
      montoInvertido: (map['monto_invertido'] as num).toDouble(),
      tasaRendimiento: map['tasa_rendimiento'] != null
          ? (map['tasa_rendimiento'] as num).toDouble()
          : null,
      periodoTasa: map['periodo_tasa'] as String? ?? 'anual',
      gananciaProyectada: map['ganancia_proyectada'] != null
          ? (map['ganancia_proyectada'] as num).toDouble()
          : null,
      gananciaObtenida: map['ganancia_obtenida'] != null
          ? (map['ganancia_obtenida'] as num).toDouble()
          : null,
      fecha: DateFormat('yyyy-MM-dd').parse(map['fecha'] as String),
      notas: map['notas'] as String?,
      estado: map['estado'] as String? ?? estadoActiva,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}