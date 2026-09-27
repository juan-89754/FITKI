import '../../data/models/investment.dart';

/// Lógica del módulo de inversiones.
///
/// Convenciones de tasas:
/// - `Investment.periodoTasa` declara el período de la tasa ingresada
///   ('anual' | 'mensual'). Es la referencia explícita para todo cálculo.
/// - Todas las proyecciones usan interés SIMPLE (sin capitalización) sobre
///   un número de períodos dado, para que el resultado sea fácil de auditar.
/// - La conversión entre períodos se hace SIEMPRE de forma explícita: si el
///   período pedido difiere del guardado, la tasa se convierte antes de
///   proyectar. Nunca se asume silenciosamente que coinciden.
class InversionesLogic {
  // Número de períodos de cada unidad de tasa dentro de un año.
  static const int _periodosPorAnioAnual = 1;
  static const int _periodosPorAnioMensual = 12;

  static int _periodosPorAnio(String periodo) =>
      periodo == 'mensual' ? _periodosPorAnioMensual : _periodosPorAnioAnual;

  /// Convierte la tasa de rendimiento declarada por la inversión al período
  /// pedido, manteniendo equivalencia de interés simple.
  ///
  /// Fórmula:
  ///   tasa_nuevo_periodo = tasa_guardada *
  ///     (períodos_por_año[guardada] / períodos_por_año[nuevo])
  ///
  /// Ejemplos (números en porcentaje, ej. 12 = 12%):
  ///   tasa anual 12% → mensual: 12 * (1/12)  = 1   (% por mes)
  ///   tasa mensual 1% → anual:   1 * (12/1)  = 12  (% al año)
  static double tasaEnPeriodo(Investment inversion, String periodoDestino) {
    final periodosOrigen = _periodosPorAnio(inversion.periodoTasa);
    final periodosDestino = _periodosPorAnio(periodoDestino);
    if (inversion.tasaRendimiento == null) return 0;
    return inversion.tasaRendimiento! * (periodosOrigen / periodosDestino);
  }

  /// Ganancia proyectada de una inversión a interés simple.
  ///
  /// Fórmula:
  ///   ganancia = monto_invertido * (tasa_en_periodo / 100) * número_períodos
  ///
  /// `tasa_en_periodo` se obtiene vía [tasaEnPeriodo] proyectando en el
  /// período solicitado: si este difiere de `periodoTasa`, la tasa se
  /// convierte explícitamente antes de multiplicar.
  static double gananciaProyectada(
    Investment inversion, {
    String periodoProyeccion = 'anual',
    double numeroPeriodos = 1,
  }) {
    final tasa = tasaEnPeriodo(inversion, periodoProyeccion);
    return inversion.montoInvertido * (tasa / 100) * numeroPeriodos;
  }

  /// Compara la ganancia REAL (ingresada por el usuario, si existe) contra la
  /// proyectada, y reporta el rendimiento efectivamente logrado.
  ///
  /// Fórmulas:
  ///   rendimiento_porcentaje = ganancia_obtenida / monto_invertido * 100
  ///   diferencia             = ganancia_obtenida - ganancia_proyectada
  /// Devuelve null si la inversión no tiene ganancia obtenida registrada o si
  /// el monto invertido no es mayor a 0 (división indefinida).
  static RendimientoInversion? rendimientoReal(
    Investment inversion, {
    String periodoProyeccion = 'anual',
  }) {
    if (inversion.montoInvertido <= 0) return null;
    final gananciaObtenida = inversion.gananciaObtenida;
    if (gananciaObtenida == null) return null;
    final proyectada = gananciaProyectada(
      inversion,
      periodoProyeccion: periodoProyeccion,
    );
    final rendimientoPorcentaje =
        gananciaObtenida / inversion.montoInvertido * 100;
    return RendimientoInversion(
      gananciaProyectada: proyectada,
      gananciaObtenida: gananciaObtenida,
      rendimientoPorcentaje: rendimientoPorcentaje,
      diferencia: gananciaObtenida - proyectada,
    );
  }

  /// Clave de agrupación de una inversión. Los tipos fuera de
  /// `Investment.tiposValidos` (dato legado o corrupto) se agrupan como
  /// 'otro' para que ninguna inversión quede invisible en los resúmenes.
  static String tipoGrupo(Investment inversion) =>
      Investment.tiposValidos.contains(inversion.tipo)
          ? inversion.tipo
          : 'otro';

  /// Agrupa las inversiones por tipo (preservando el orden de
  /// `Investment.tiposValidos`) y totaliza por grupo:
  ///   total_invertido = Σ monto_invertido del grupo
  ///   ganancia_total  = Σ ganancia_obtenida del grupo (inversiones sin
  ///                     ganancia registrada aportan 0)
  static List<ResumenInversionPorTipo> resumenPorTipo(
    List<Investment> inversiones,
  ) {
    final grupos = <String, List<Investment>>{};
    for (final inversion in inversiones) {
      grupos.putIfAbsent(tipoGrupo(inversion), () => []).add(inversion);
    }
    return Investment.tiposValidos
        .where((tipo) => grupos.containsKey(tipo))
        .map((tipo) {
      final items = grupos[tipo]!;
      final totalInvertido = items.fold<double>(
        0,
        (acumulado, inversion) => acumulado + inversion.montoInvertido,
      );
      final gananciaTotal = items.fold<double>(
        0,
        (acumulado, inversion) => acumulado + (inversion.gananciaObtenida ?? 0),
      );
      return ResumenInversionPorTipo(
        tipo: tipo,
        totalInvertido: totalInvertido,
        gananciaTotal: gananciaTotal,
        cantidad: items.length,
      );
    }).toList();
  }

  static const Map<String, String> _tipoLabels = {
    'divisas': 'Divisas',
    'bolsa': 'Bolsa',
    'mercancias': 'Mercancías',
    'eventos': 'Eventos',
    'otro': 'Otro',
  };

  static String labelTipo(String tipo) => _tipoLabels[tipo] ?? 'Otro';

  static const Map<String, String> _periodoLabels = {
    'anual': 'anual',
    'mensual': 'mensual',
  };

  static String labelPeriodo(String periodo) =>
      _periodoLabels[periodo] ?? 'anual';

  /// Período corto ('mes' / 'año') para etiquetas de proyección.
  static String labelPeriodoCorto(String periodo) =>
      periodo == 'mensual' ? 'mes' : 'año';
}

/// Resultado de comparar la ganancia obtenida contra la proyectada.
class RendimientoInversion {
  final double gananciaProyectada;
  final double gananciaObtenida;

  /// Rendimiento logrado expresado como porcentaje sobre el monto invertido.
  final double rendimientoPorcentaje;

  /// ganancia_obtenida - ganancia_proyectada (positivo = supera proyección).
  final double diferencia;

  bool get superaProyectada => diferencia >= 0;

  const RendimientoInversion({
    required this.gananciaProyectada,
    required this.gananciaObtenida,
    required this.rendimientoPorcentaje,
    required this.diferencia,
  });
}

/// Totales de inversión agrupados por tipo.
class ResumenInversionPorTipo {
  final String tipo;
  final double totalInvertido;
  final double gananciaTotal;
  final int cantidad;

  const ResumenInversionPorTipo({
    required this.tipo,
    required this.totalInvertido,
    required this.gananciaTotal,
    required this.cantidad,
  });
}