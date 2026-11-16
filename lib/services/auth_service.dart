import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class AuthService extends ChangeNotifier {
  final DatabaseHelper dbHelper;
  Map<String, dynamic>? _currentUser;

  AuthService(this.dbHelper);

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login(String dni, String password) async {
    final db = await dbHelper.database;
    
    // 1. Validar credenciales en la tabla personal
    var user = await db.query('personal', 
      where: 'dni = ? AND password = ? AND activo = 1', 
      whereArgs: [dni, password]); 
    
    if (user.isNotEmpty) {
      Map<String, dynamic> usuario = Map<String, dynamic>.from(user.first);

      // 2. Si es VENDEDOR, buscar su asignación de HOY
      if (usuario['rol'] == 'VENDEDOR') {
        final hoy = DateTime.now().toIso8601String().split('T')[0];
        final asignacion = await db.query('asignaciones_diarias',
            where: 'usuario_id = ? AND fecha = ? AND estado = ?',
            whereArgs: [usuario['id'], hoy, 'ACTIVO']);
        
        if (asignacion.isNotEmpty) {
          // Guardamos el PV que el admin le asignó para hoy
          usuario['punto_venta_id_actual'] = asignacion.first['punto_venta_id'];
        } else {
          // Si no tiene asignación hoy, el login_screen lo bloqueará, 
          // pero le ponemos un 0 para que no explote.
          usuario['punto_venta_id_actual'] = 0; 
        }
      } else {
        // Si es ADMIN, no opera en calle, así que su PV actual es 0
        usuario['punto_venta_id_actual'] = 0; 
      }

      _currentUser = usuario; 
      notifyListeners(); 
      return true; 
    }
    return false; 
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}