import 'package:flutter/foundation.dart'; // REM: Fundamentos de Flutter para ChangeNotifier
import 'database_helper.dart'; // REM: Importa el cerebro de datos que acabamos de crear

class AuthService extends ChangeNotifier { // REM: Servicio de autenticación que notifica cambios de estado
  final DatabaseHelper dbHelper; // REM: Dependencia inyectada para acceder a la base de datos
  Map<String, dynamic>? _currentUser; // REM: Variable privada que guarda los datos del usuario logueado

  AuthService(this.dbHelper); // REM: Constructor que recibe la instancia de DatabaseHelper

  Map<String, dynamic>? get currentUser => _currentUser; // REM: Getter público para leer el usuario actual
  bool get isLoggedIn => _currentUser != null; // REM: Getter booleano para saber si hay sesión activa

  Future<bool> login(String dni, String password) async { // REM: Función asíncrona de inicio de sesión
    final db = await dbHelper.database; // REM: Obtiene la instancia de la base de datos
    // REM: Busca en la tabla 'personal' coincidiendo DNI, contraseña y que esté activo (1)
    var user = await db.query('personal', 
      where: 'dni = ? AND password = ? AND activo = 1', 
      whereArgs: [dni, password]); 
    
    if (user.isNotEmpty) { // REM: Si la consulta devuelve al menos un registro
      _currentUser = user.first; // REM: Guarda ese usuario en la memoria de la sesión
      notifyListeners(); // REM: Avisa a toda la app (ej. main.dart) que el estado de login cambió
      return true; // REM: Retorna éxito
    }
    return false; // REM: Retorna fallo si no encontró coincidencias
  }

  void logout() { // REM: Función para cerrar sesión
    _currentUser = null; // REM: Limpia la memoria del usuario actual
    notifyListeners(); // REM: Avisa a la app que se cerró la sesión (para volver al Login)
  }
}
