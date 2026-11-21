import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'password_service.dart';

class AuthService extends ChangeNotifier {
  final DatabaseHelper _db;
  Map<String, dynamic>? _currentUser;
  String _lastError = '';

  AuthService(this._db);

  Map<String, dynamic>? get currentUser => _currentUser;
  String get lastError => _lastError;

  Future<bool> login(String dni, String password) async {
    _lastError = '';
    final db = await _db.database;
    final users = await db.query('personal', where: 'dni = ? AND activo = 1', whereArgs: [dni]);

    if (users.isEmpty) {
      _lastError = 'DNI o contraseña incorrectos';
      return false;
    }

    // QueryRow es read-only: convertimos a Map mutable
    final user = Map<String, dynamic>.from(users.first);
    final storedPassword = user['password'] as String? ?? '';

    if (storedPassword.isEmpty) {
      _lastError = 'Usuario sin contraseña registrada';
      return false;
    }

    // Migración transparente de contraseñas antiguas en texto plano
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
        _lastError = 'DNI o contraseña incorrectos';
        return false;
      }
    } else {
      if (!PasswordService.verifyPassword(password, storedPassword)) {
        _lastError = 'DNI o contraseña incorrectos';
        return false;
      }
    }

    // Validación de horario: SOLO aplica a VENDEDOR y CAJERO.
    // ADMIN y VENDEDOR_BETA entran sin restricción de horario.
    final rol = user['rol'] as String? ?? '';
    if (rol == 'VENDEDOR' || rol == 'CAJERO') {
      final pvId = user['punto_venta_id'] as int?;
      if (pvId != null && pvId != 0) {
        final pvRows = await db.query('puntos_venta', where: 'id = ?', whereArgs: [pvId]);
        if (pvRows.isNotEmpty) {
          final pv = Map<String, dynamic>.from(pvRows.first);
          final ini = pv['ini_vta'] as String? ?? '00:00';
          final fin = pv['fin_vta'] as String? ?? '23:59';
          if (!_dentroDeHorario(ini, fin)) {
            _lastError = 'Fuera del horario de atención ($ini - $fin). '
                'Usa un VENDEDOR BETA para probar fuera de horario.';
            return false;
          }
        }
      }
    }

    _currentUser = user;
    notifyListeners();
    return true;
  }

  bool _dentroDeHorario(String ini, String fin) {
    final ahora = DateTime.now();
    final h = ahora.hour;
    final m = ahora.minute;
    final actual = h * 60 + m;

    final iniPartes = ini.split(':');
    final finPartes = fin.split(':');
    final iniMin = (int.tryParse(iniPartes[0]) ?? 0) * 60 + (int.tryParse(iniPartes[1]) ?? 0);
    final finMin = (int.tryParse(finPartes[0]) ?? 0) * 60 + (int.tryParse(finPartes[1]) ?? 0);

    if (iniMin <= finMin) {
      // Horario normal dentro del mismo día (ej: 03:00 - 11:00)
      return actual >= iniMin && actual <= finMin;
    } else {
      // Horario que cruza medianoche (ej: 20:00 - 06:00)
      return actual >= iniMin || actual <= finMin;
    }
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

    // Reemplazamos con una copia mutable (QueryRow es read-only)
    _currentUser = Map<String, dynamic>.from(_currentUser!)
      ..['password'] = newHash
      ..['requiere_cambio_password'] = 0;

    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    _lastError = '';
    notifyListeners();
  }
}