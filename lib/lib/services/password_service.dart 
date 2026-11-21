import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordService {
  /// Genera un hash seguro con sal aleatoria de 16 bytes (32 caracteres hex).
  /// Formato de retorno: "sal_hex:hash_hex"
  static String hashPassword(String password) {
    final random = Random.secure();
    final sal = List<int>.generate(16, (_) => random.nextInt(256));
    final salHex = sal.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final hash = sha256.convert(utf8.encode('$salHex:$password')).toString();
    return '$salHex:$hash';
  }

  /// Verifica si una contraseña coincide con un hash almacenado.
  /// Usa comparación en tiempo constante para no filtrar información.
  static bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salHex = parts[0];
    final hash = parts[1];
    final computed = sha256.convert(utf8.encode('$salHex:$password')).toString();
    
    int result = 0;
    if (hash.length != computed.length) return false;
    for (int i = 0; i < hash.length; i++) {
      result |= hash.codeUnitAt(i) ^ computed.codeUnitAt(i);
    }
    return result == 0;
  }
}