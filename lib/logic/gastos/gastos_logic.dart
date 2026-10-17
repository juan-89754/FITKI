import '../../data/models/loan.dart';
import '../../data/models/transaction.dart';

/// Lógica de gastos: agregados por categoría contra el historial real de
/// movimientos.
///
/// Es un módulo puro: recibe datos y devuelve resultados, sin depender de
/// widgets ni de providers. Toda la aritmética de la app vive aquí para que
/// las pantallas solo pinten lo que este código calcula.
///
/// Nada de esto guarda límites ni topes: AFCA es quien decide cuánto se puede
/// asignar a un bolsillo (y por cuánto tiempo), mientras acá solo se mide lo
/// que de verdad se gastó.
class GastosLogic {
  static const String tipoGasto = Transaction.tipoGasto;

  /// Suma lo gastado en una categoría concreta dentro de un mes.
  static double totalDeCategoria({
    required List<Transaction> movimientos,
    required String categoria,
    required int mes,
    required int anio,
  }) {
    final inicio = DateTime(anio, mes, 1);
    final fin = DateTime(anio, mes + 1, 0);
    var total = 0.0;
    for (final movimiento in movimientos) {
      if (movimiento.tipo != tipoGasto) continue;
      if (movimiento.categoria != categoria) continue;
      if (movimiento.fecha.isBefore(inicio) || movimiento.fecha.isAfter(fin)) {
        continue;
      }
      total += movimiento.monto;
    }
    return total;
  }

  /// Cuánto se gastó en el mes en cada categoría. Es lo que permite listar las
  /// categorías con gasto real al lado de las que ya tienen un bolsillo, para
  /// sugerir solas cuáles conviene asignar. Los préstamos a terceros se
  /// excluyen: prestar no es consumir.
  static Map<String, double> gastadoPorCategoria({
    required List<Transaction> movimientos,
    required int mes,
    required int anio,
  }) {
    final inicio = DateTime(anio, mes, 1);
    final fin = DateTime(anio, mes + 1, 0);
    final resultado = <String, double>{};
    for (final movimiento in movimientos) {
      if (movimiento.tipo != tipoGasto) continue;
      if (movimiento.categoria == Loan.categoriaPrestamo) continue;
      if (movimiento.fecha.isBefore(inicio) || movimiento.fecha.isAfter(fin)) {
        continue;
      }
      resultado[movimiento.categoria] =
          (resultado[movimiento.categoria] ?? 0) + movimiento.monto;
    }
    return resultado;
  }

  /// Promedio mensual de lo gastado en una categoría en los [meses] meses
  /// anteriores al mes pedido (sin incluirlo). Es la base con la que un
  /// formulario propone un monto asignado con datos reales en vez de inventar
  /// la cifra; un gasto fijo entra solo porque al pagarse genera su movimiento.
  /// Devuelve null cuando no hay historial: sin nada contra lo que comparar,
  /// un 0 mentiría.
  static double? promedioMensualCategoria({
    required List<Transaction> movimientos,
    required String categoria,
    required int mes,
    required int anio,
    int meses = 3,
  }) {
    final porPeriodo = <int, double>{};
    for (var i = 1; i <= meses; i++) {
      final fecha = DateTime(anio, mes - i, 1);
      porPeriodo[fecha.year * 100 + fecha.month] = 0;
    }
    for (final movimiento in movimientos) {
      if (movimiento.tipo != tipoGasto) continue;
      if (movimiento.categoria != categoria) continue;
      final clave = movimiento.fecha.year * 100 + movimiento.fecha.month;
      if (!porPeriodo.containsKey(clave)) continue;
      porPeriodo[clave] = porPeriodo[clave]! + movimiento.monto;
    }
    final conGasto = porPeriodo.values.where((v) => v > 0).toList();
    if (conGasto.isEmpty) return null;
    return conGasto.fold<double>(0, (acc, v) => acc + v) / conGasto.length;
  }
}
