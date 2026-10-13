import 'package:flutter/material.dart';

import '../format/app_format.dart';

/// Apila los montos de un desglose por moneda, una línea por moneda, para los
/// números grandes de las cabeceras. Con una sola moneda muestra una única
/// línea, igual que antes; con varias, cada una en su renglón con su símbolo,
/// para que nadie sume monedas distintas como si fueran lo mismo.
class TotalesPorMoneda extends StatelessWidget {
  final Map<String, double> totales;
  final TextStyle style;
  final TextAlign? textAlign;

  const TotalesPorMoneda({
    super.key,
    required this.totales,
    required this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final porMoneda = totales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (porMoneda.isEmpty) {
      return Text(
        AppFormat.moneda(0),
        style: style,
        textAlign: textAlign,
      );
    }

    final centrado = textAlign == TextAlign.center;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centrado ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        for (final entry in porMoneda)
          Text(
            AppFormat.monedaPorCodigo(entry.value, entry.key),
            style: style,
            textAlign: textAlign,
          ),
      ],
    );
  }
}