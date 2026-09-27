import 'package:intl/intl.dart';

/// Un mes concreto. Lo comparten el presupuesto y los gastos fijos para que
/// "octubre" signifique exactamente lo mismo en las dos pantallas, y para
/// poder navegar entre meses en lugar de mirar siempre el actual.
class Periodo {
  final int mes;
  final int anio;

  const Periodo(this.mes, this.anio);

  factory Periodo.de(DateTime fecha) => Periodo(fecha.month, fecha.year);

  factory Periodo.actual() => Periodo.de(DateTime.now());

  static const List<String> nombresMes = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// "Octubre 2026"
  String get etiqueta => '${nombresMes[mes - 1]} $anio';

  /// "Oct 2026", para encabezado compacto.
  String get etiquetaCorta {
    final corto = DateFormat('MMM', 'es').format(DateTime(anio, mes, 1));
    return '${corto[0].toUpperCase()}${corto.substring(1)} $anio';
  }

  bool esActual() {
    final ahora = DateTime.now();
    return mes == ahora.month && anio == ahora.year;
  }

  bool esFuturo() {
    final ahora = DateTime.now();
    return anio > ahora.year || (anio == ahora.year && mes > ahora.month);
  }

  /// true cuando el mes todavía no termina, para poder mostrar "llevas gastado
  /// X de Y" con la expectativa de que aún queda mes por delante.
  bool enCurso() {
    final ahora = DateTime.now();
    return anio == ahora.year && mes == ahora.month;
  }

  Periodo get anterior =>
      mes == 1 ? Periodo(12, anio - 1) : Periodo(mes - 1, anio);

  Periodo get siguiente => mes == 12 ? Periodo(1, anio + 1) : Periodo(mes + 1, anio);

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.mes == mes && other.anio == anio;

  @override
  int get hashCode => Object.hash(mes, anio);
}
