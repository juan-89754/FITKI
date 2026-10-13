/// Carga de deuda mensual: suma de cuotas activas vs. ingresos del mes.
/// El umbral frente al que se compara la carga es configurable por el usuario
/// (se persiste en AppPreferences) y se pasa por parámetro desde quien hace
/// el cálculo, de modo que esta lógica no depende de un porcentaje fijo.
class CargaDeuda {
  final double cuotaMensualTotal;
  final double ingresosMensuales;

  /// Cuánto pesan las cuotas sobre los ingresos del mes, en porcentaje. Es
  /// `null` cuando no hay ingresos registrados: sin una base contra la que
  /// comparar, el 0% mentiría (una cuota cualquiera sobre ingresos 0 no es
  /// "0% de carga", es "no se puede calcular"). La UI muestra "—" en ese caso.
  final double? porcentaje;

  /// Fracción (0-1) de los ingresos a partir de la cual la carga se considera
  /// riesgosa (p. ej. 0.40 = 40%).
  final double umbral;

  bool get excedeUmbral => porcentaje != null && porcentaje! > umbral * 100;

  const CargaDeuda({
    required this.cuotaMensualTotal,
    required this.ingresosMensuales,
    required this.porcentaje,
    required this.umbral,
  });
}

/// Calcula la carga de deuda a partir de la cuota mensual total y los
/// ingresos del mes, comparándola contra el [umbral] configurado
/// (fracción 0-1, p. ej. 0.40). Con ingresos en cero no hay porcentaje.
CargaDeuda calcularCargaDeuda(
  double cuotaMensualTotal,
  double ingresosMensuales, {
  required double umbral,
}) {
  final porcentaje = ingresosMensuales > 0
      ? (cuotaMensualTotal / ingresosMensuales) * 100
      : null;
  return CargaDeuda(
    cuotaMensualTotal: cuotaMensualTotal,
    ingresosMensuales: ingresosMensuales,
    porcentaje: porcentaje,
    umbral: umbral,
  );
}