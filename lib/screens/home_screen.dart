import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/auth_service.dart'; // REM: Servicio de autenticación para leer rol del usuario
import 'venta_screen.dart'; // REM: Pantalla de ventas (accesible para todos)
import 'transferencia_screen.dart'; // REM: Pantalla de envío de stock (solo admin)
import 'recepcion_traslados_screen.dart'; // REM: Pantalla de recepción de stock y cambio inicial
import 'cierre_caja_screen.dart'; // REM: Pantalla de cierre de jornada (solo admin)
import 'rentabilidad_screen.dart'; // REM: Pantalla de reporte de ganancias (solo admin)
import 'cxc_screen.dart'; // REM: Pantalla de cuentas por cobrar (solo admin)
import 'admin_personal_screen.dart'; // REM: Pantalla de gestión de personal (solo admin)
import 'compra_screen.dart'; // REM: Pantalla de registro de gastos (solo admin)
import 'mantenimiento/mantenimiento_menu_screen.dart'; // REM: NUEVO - Menú de mantenimiento (solo admin)

class HomeScreen extends StatelessWidget { // REM: Pantalla de menú principal sin estado mutable
  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual
    final auth = Provider.of<AuthService>(context); // REM: Obtiene el servicio de autenticación
    bool isAdmin = auth.currentUser?['rol'] == 'admin'; // REM: Verifica si el usuario tiene rol de administrador
    
    return Scaffold( // REM: Estructura básica de la pantalla
      appBar: AppBar( // REM: Barra superior de la aplicación
        title: Text('MENÚ PRINCIPAL'), // REM: Título de la barra
        backgroundColor: Colors.black, // REM: Fondo negro de la barra
      ),
      backgroundColor: Colors.black, // REM: Fondo negro de toda la pantalla
      body: SingleChildScrollView( // REM: Permite scroll si hay muchos botones
        child: Column( // REM: Organiza el contenido en columna
          children: [
            // ═══════════════════════════════════════════════════
            // BOTÓN DESTACADO: MANTENIMIENTO (solo admin)
            // ═══════════════════════════════════════════════════
            if (isAdmin)
              Padding(
                padding: EdgeInsets.fromLTRB(15, 15, 15, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MantenimientoMenuScreen(),
                      ),
                    ),
                    icon: Icon(Icons.build, color: Colors.black, size: 32),
                    label: Text(
                      'MANTENIMIENTO',
                      style: TextStyle(
                        fontFamily: 'CourierNew',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            // ═══════════════════════════════════════════════════
            // GRID DE BOTONES ORIGINALES
            // ═══════════════════════════════════════════════════
            GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(15),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _btn(context, 'NUEVA VENTA', VentaScreen()),
                
                if (isAdmin) ...[
                  _btn(context, 'ENVIAR STOCK', TransferenciaScreen()),
                  _btn(context, 'GESTIÓN PERSONAL', AdminPersonalScreen()),
                  _btn(context, 'CIERRE DE CAJA', CierreCajaScreen()),
                  _btn(context, 'MI RENTABILIDAD', RentabilidadScreen()),
                  _btn(context, 'CUENTAS X COBRAR', CxcScreen()),
                  _btn(context, 'REGISTRAR GASTO', CompraScreen()),
                ],
                
                _btn(context, 'RECIBIR INICIO JORNADA', RecepcionTrasladosScreen()),
                
                ElevatedButton(
                  onPressed: () {
                    auth.logout();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  child: Text(
                    'SALIR',
                    style: TextStyle(fontFamily: 'CourierNew', fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, String title, Widget screen) { // REM: Función auxiliar para botones uniformes
    return ElevatedButton(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'CourierNew', fontSize: 14),
      ),
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}