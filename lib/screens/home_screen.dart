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
      body: SingleChildScrollView( // REM: NUEVO - Permite scroll si hay muchos botones
        child: Column( // REM: NUEVO - Organiza el contenido en columna
          children: [
            // ═══════════════════════════════════════════════════
            // BOTÓN DESTACADO: MANTENIMIENTO (solo admin)
            // ═══════════════════════════════════════════════════
            if (isAdmin)
              Padding( // REM: Margen alrededor del botón
                padding: EdgeInsets.fromLTRB(15, 15, 15, 0), // REM: Izq, arriba, der, abajo
                child: SizedBox( // REM: Contenedor con tamaño definido
                  width: double.infinity, // REM: Ancho completo
                  height: 70, // REM: Alto destacado
                  child: ElevatedButton.icon( // REM: Botón con ícono
                    onPressed: () => Navigator.push( // REM: Al presionar navega a mantenimiento
                      context,
                      MaterialPageRoute(
                        builder: (_) => MantenimientoMenuScreen(),
                      ),
                    ),
                    icon: Icon(Icons.build, color: Colors.black, size: 32), // REM: Ícono de herramienta
                    label: Text( // REM: Texto del botón
                      'MANTENIMIENTO',
                      style: TextStyle(
                        fontFamily: 'CourierNew',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    style: ElevatedButton.styleFrom( // REM: Estilo especial
                      backgroundColor: Colors.orange, // REM: Naranja para destacarlo
                      foregroundColor: Colors.black, // REM: Texto negro
                      shape: RoundedRectangleBorder( // REM: Bordes redondeados
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            // ═══════════════════════════════════════════════════
            // GRID DE BOTONES ORIGINALES
            // ═══════════════════════════════════════════════════
            GridView.count( // REM: Cuadrícula de botones
              crossAxisCount: 2, // REM: Dos columnas
              padding: EdgeInsets.all(15), // REM: Margen interno
              crossAxisSpacing: 15, // REM: Espacio horizontal
              mainAxisSpacing: 15, // REM: Espacio vertical
              shrinkWrap: true, // REM: NUEVO - Permite anidar en Column
              physics: NeverScrollableScrollPhysics(), // REM: NUEVO - Desactiva scroll propio
              children: [
                _btn(context, 'NUEVA VENTA', VentaScreen()), // REM: Botón de venta
                
                if (isAdmin) ...[ // REM: Botones solo para admin
                  _btn(context, 'ENVIAR STOCK', TransferenciaScreen()),
                  _btn(context, 'GESTIÓN PERSONAL', AdminPersonalScreen()),
                  _btn(context, 'CIERRE DE CAJA', CierreCajaScreen()),
                  _btn(context, 'MI RENTABILIDAD', RentabilidadScreen()),
                  _btn(context, 'CUENTAS X COBRAR', CxcScreen()),
                  _btn(context, 'REGISTRAR GASTO', CompraScreen()),
                ],
                
                _btn(context, 'RECIBIR INICIO JORNADA', RecepcionTrasladosScreen()),
                
                ElevatedButton( // REM: Botón de salir
                  onPressed: () {
                    auth.logout();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  child: Text('SALIR', style: TextStyle(fontFamily: 'CourierNew', fontSize: 14)),
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
    return ElevatedButton( // REM: Botón elevado
      child: Text( // REM: Texto
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'CourierNew', fontSize: 14)
      ),
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen)), // REM: Navega a la pantalla
    );
  }
}