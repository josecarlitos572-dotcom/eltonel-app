import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'password_service.dart';

class AuthService extends ChangeNotifier {
  final DatabaseHelper _db;
  Map<String, dynamic>? _currentUser;

  AuthService(this._db);

  Map<String, dynamic>? get currentUser => _currentUser;

  Future<bool> login(String dni, String password) async {
    final db = await _db.database;
    final users = await db.query('personal', where: 'dni = ? AND activo = 1', whereArgs: [dni]);

    if (users.isEmpty) return false;

    // CONVERTIR QueryRow (read-only) a Map mutable
    final user = Map<String, dynamic>.from(users.first);
    final storedPassword = user['password'] as String? ?? '';

    if (storedPassword.isEmpty) return false;

    // Migración transparente: si la contraseña no tiene formato de hash (no contiene ':')
    if (!storedPassword.contains(':')) {
      if (storedPassword == password) {
        final newHash = PasswordService.hashPassword(password);
        await db.update('personal', {
          'password': newHash,
          'requiere_cambio_password': 1,
        }, where: 'id = ?', whereArgs: [user['id']]);
        user['password'] = newHash;
        user['requiere_cambio_password'] = 1;
      } else {
        return false;
      }
    } else {
      if (!PasswordService.verifyPassword(password, storedPassword)) {
        return false;
      }
    }

    _currentUser = user;
    notifyListeners();
    return true;
  }

  Future<bool> cambiarPassword(String nuevoPassword) async {
    if (_currentUser == null) return false;
    if (nuevoPassword.length < 6) return false;

    final db = await _db.database;
    final newHash = PasswordService.hashPassword(nuevoPassword);
    await db.update('personal', {
      'password': newHash,
      'requiere_cambio_password': 0,
    }, where: 'id = ?', whereArgs: [_currentUser!['id']]);

    // REEMPLAZAR el objeto completo con una copia mutable actualizada
    _currentUser = Map<String, dynamic>.from(_currentUser!)
      ..['password'] = newHash
      ..['requiere_cambio_password'] = 0;

    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}