import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Genera el hash del PIN (sha256 del valor textual). El PIN NUNCA se guarda
/// en texto plano: solo este hash viaja a flutter_secure_storage, de modo que
/// un respaldo o un volcado de preferencias no exponga el PIN.
String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();