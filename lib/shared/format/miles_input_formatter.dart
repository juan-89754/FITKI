import 'package:flutter/services.dart';

/// Formatea un monto en vivo mientras el usuario escribe: deja solo dígitos
/// y los agrupa con puntos de miles (estilo es_CO) sin decimales, p. ej.
/// escribir "1500000" se muestra como "1.500.000".
///
/// Al reformatear reubica el cursor sobre el mismo dígito que se estaba
/// editando, de modo que escribir o borrar en medio del texto no salte el
/// cursor al final.
class MilesInputFormatter extends TextInputFormatter {
  const MilesInputFormatter();

  static final RegExp _soloDigitos = RegExp(r'[^0-9]');
  static final RegExp _cerosIniciales = RegExp(r'^0+(?=\d)');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final cursor = newValue.selection.extentOffset.clamp(0, text.length);
    final digitosAntesCursor =
        text.substring(0, cursor).replaceAll(_soloDigitos, '').length;

    final digitos = text.replaceAll(_soloDigitos, '');
    if (digitos.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final sinCeros = digitos.replaceFirst(_cerosIniciales, '');
    if (sinCeros.isEmpty) {
      return newValue.copyWith(
        text: '0',
        selection: const TextSelection.collapsed(offset: 1),
      );
    }

    final cerosQuitados = digitos.length - sinCeros.length;
    final formateado = _formatearMiles(sinCeros);

    final k = (digitosAntesCursor - cerosQuitados).clamp(0, sinCeros.length);
    final offset = _offsetDelDigito(k, formateado);

    return newValue.copyWith(
      text: formateado,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static String _formatearMiles(String digitos) {
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digitos[i]);
    }
    return buffer.toString();
  }

  /// Posición en [formateado] justo después del dígito número [k]
  /// (0 = antes del primero; igual a la cantidad de dígitos = al final).
  static int _offsetDelDigito(int k, String formateado) {
    if (k <= 0) return 0;
    var vistos = 0;
    for (var i = 0; i < formateado.length; i++) {
      final char = formateado.codeUnitAt(i);
      if (char >= 0x30 && char <= 0x39) {
        vistos++;
        if (vistos == k) return i + 1;
      }
    }
    return formateado.length;
  }
}

/// Convierte a [double] un monto escrito con separadores de miles
/// (p. ej. "1.500.000"), ignorando cualquier carácter no numérico.
/// Devuelve `null` si no hay dígitos.
double? milesADouble(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final digitos = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return null;
  return double.tryParse(digitos);
}