import 'package:intl/intl.dart';

/// Un movimiento dentro de una inversión: aportar o retirar capital, o
/// registrar una ganancia o una pérdida ya realizada.
///
/// Igual que un aporte a una meta, esto **no mueve dinero de la cuenta**: el
/// capital sigue en el activo, solo cambia de "disponible" a "reservado en la
/// inversión". Por eso un `aporte` no escribe un movimiento de gasto ni toca
/// `activos.monto_disponible`; retirar hace lo contrario.
///
/// La [tipoGanancia] y la [tipoPerdida] son el resultado que el usuario va
/// observando. Viven aquí, como detalle de la inversión, y **no** tocan la
/// cuenta: solo cuando la inversión se finaliza, el resultado neto se registra
/// como un movimiento real (ingreso si ganó, gasto si perdió).
class InversionMovimiento {
  final int? id;
  final int inversionId;

  /// [tipoAporte] reserva capital, [tipoRetiro] lo libera, [tipoGanancia] y
  /// [tipoPerdida] anotan el resultado del periodo.
  final String tipo;
  final double monto;
  final DateTime fecha;

  /// Cuenta de la que sale el capital en un aporte, o a la que vuelve en un
  /// retiro. Sin cascada: si la cuenta se borra, el historial se conserva.
  final int? activoId;

  final String? nota;
  final DateTime fechaCreacion;

  static const String tableName = 'inversiones_movimientos';

  static const String tipoAporte = 'aporte';
  static const String tipoRetiro = 'retiro';
  static const String tipoGanancia = 'ganancia';
  static const String tipoPerdida = 'perdida';

  static const List<String> tiposValidos = [
    tipoAporte,
    tipoRetiro,
    tipoGanancia,
    tipoPerdida,
  ];

  const InversionMovimiento({
    this.id,
    required this.inversionId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.activoId,
    this.nota,
    required this.fechaCreacion,
  });

  bool get esAporte => tipo == tipoAporte;
  bool get esRetiro => tipo == tipoRetiro;
  bool get esGanancia => tipo == tipoGanancia;
  bool get esPerdida => tipo == tipoPerdida;

  /// Afecta el capital reservado: un aporte lo sube, un retiro lo baja. Las
  /// ganancias y pérdidas no tocan el capital, solo el resultado.
  bool get afectaCapital => esAporte || esRetiro;

  /// Afecta el resultado neto de la inversión.
  bool get afectaResultado => esGanancia || esPerdida;

  /// Monto con signo dentro del capital reservado (aporte suma, retiro resta).
  double get capitalConSigno => esRetiro ? -monto : monto;

  /// Monto con signo dentro del resultado (ganancia suma, pérdida resta).
  double get resultadoConSigno => esPerdida ? -monto : monto;

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      inversion_id INTEGER NOT NULL,
      tipo TEXT NOT NULL,
      monto REAL NOT NULL,
      fecha TEXT NOT NULL,
      activo_id INTEGER,
      nota TEXT,
      fecha_creacion TEXT NOT NULL,
      FOREIGN KEY (inversion_id) REFERENCES inversiones(id) ON DELETE CASCADE,
      FOREIGN KEY (activo_id) REFERENCES activos(id) ON DELETE SET NULL
    )
  ''';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'inversion_id': inversionId,
      'tipo': tipo,
      'monto': monto,
      'fecha': DateFormat('yyyy-MM-dd').format(fecha),
      'activo_id': activoId,
      'nota': nota,
      'fecha_creacion': DateFormat('yyyy-MM-dd HH:mm:ss').format(fechaCreacion),
    };
  }

  factory InversionMovimiento.fromMap(Map<String, dynamic> map) {
    return InversionMovimiento(
      id: map['id'] as int?,
      inversionId: map['inversion_id'] as int,
      tipo: map['tipo'] as String,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateFormat('yyyy-MM-dd').parse(map['fecha'] as String),
      activoId: map['activo_id'] as int?,
      nota: map['nota'] as String?,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss')
          .parse(map['fecha_creacion'] as String),
    );
  }
}