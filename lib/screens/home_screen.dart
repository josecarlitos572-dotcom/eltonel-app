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
      body: GridView.count( // REM: Cuadrícula de botones organizada en filas y columnas
        crossAxisCount: 2, // REM: Dos columnas de botones
        padding: EdgeInsets.all(15), // REM: Margen de 15 píxeles alrededor
        crossAxisSpacing: 15, // REM: Espacio horizontal entre botones
        mainAxisSpacing: 15, // REM: Espacio vertical entre botones
        children: [
          _btn(context, 'NUEVA VENTA', VentaScreen()), // REM: Botón de venta (visible para todos los roles)
          
          if (isAdmin) ...[ // REM: Bloque condicional: solo se muestra si el usuario es admin
            _btn(context, 'ENVIAR STOCK', TransferenciaScreen()), // REM: Botón para trasladar stock entre puntos
            _btn(context, 'GESTIÓN PERSONAL', AdminPersonalScreen()), // REM: Botón para crear/editar usuarios
            _btn(context, 'CIERRE DE CAJA', CierreCajaScreen()), // REM: Botón para cerrar jornada y cuadrar caja
            _btn(context, 'MI RENTABILIDAD', RentabilidadScreen()), // REM: Botón para ver ganancias del mes
            _btn(context, 'CUENTAS X COBRAR', CxcScreen()), // REM: Botón para ver deudas de clientes
            _btn(context, 'REGISTRAR GASTO', CompraScreen()), // REM: Botón para registrar gastos operativos
          ],
          
          _btn(context, 'RECIBIR INICIO JORNADA', RecepcionTrasladosScreen()), // REM: Botón para cargar stock y cambio inicial (todos los roles)
          
          ElevatedButton( // REM: Botón de salir del sistema
            onPressed: () { // REM: Acción al presionar
              auth.logout(); // REM: Cierra la sesión del usuario
              Navigator.pushReplacementNamed(context, '/'); // REM: Vuelve a la pantalla de login
            },
            child: Text('SALIR'), // REM: Texto del botón
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), // REM: Color rojo para indicar acción de salida
          )
        ],
      ),
    );
  }

  Widget _btn(BuildContext ctx, String title, Widget screen) { // REM: Función auxiliar para crear botones uniformes
    return ElevatedButton( // REM: Crea un botón elevado con estilo
      child: Text( // REM: Texto dentro del botón
        title, // REM: Título del botón (ej: 'NUEVA VENTA')
        textAlign: TextAlign.center, // REM: Texto centrado
        style: TextStyle(fontFamily: 'CourierNew', fontSize: 14) // REM: Fuente Courier New, tamaño 14
      ),
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen)), // REM: Al presionar, navega a la pantalla correspondiente
    );
  }
}
