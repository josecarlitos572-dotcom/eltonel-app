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
    
    var user = await db.query('personal', 
      where: 'dni = ? AND password = ? AND activo = 1', 
      whereArgs: [dni, password]); 
    
    if (user.isNotEmpty) {
      Map<String, dynamic> usuario = Map<String, dynamic>.from(user.first);

      // Si es vendedor, buscamos a qué punto de venta está asignado HOY
      if (usuario['rol'] == 'VENDEDOR') {
        final hoy = DateTime.now().toIso8601String().split('T')[0];
        final asignacion = await db.query('asignaciones_diarias',
            where: 'usuario_id = ? AND fecha = ? AND estado = ?',
            whereArgs: [usuario['id'], hoy, 'ACTIVO']);
        
        if (asignacion.isNotEmpty) {
          usuario['punto_venta_id_actual'] = asignacion.first['punto_venta_id'];
        } else {
          // Si no hay asignación, el login fallará en el screen. 
          // Le ponemos un valor por defecto para que no rompa.
          usuario['punto_venta_id_actual'] = 0; 
        }
      } else {
        // Si es ADMIN, no tiene punto de venta fijo
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