import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica de Flutter
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/auth_service.dart'; // REM: Servicio de autenticación que valida credenciales
import 'home_screen.dart'; // REM: Pantalla de menú principal a la que se irá tras el login

class LoginScreen extends StatefulWidget { // REM: Define la pantalla de login como un widget con estado mutable
  @override
  _LoginScreenState createState() => _LoginScreenState(); // REM: Crea el estado interno de esta pantalla
}

class _LoginScreenState extends State<LoginScreen> { // REM: Lógica interna y estado del login
  final TextEditingController _dniCtrl = TextEditingController(); // REM: Controlador para el campo de texto del DNI
  final TextEditingController _passCtrl = TextEditingController(); // REM: Controlador para el campo de texto de la contraseña

  void _login() async { // REM: Función asíncrona que se ejecuta al presionar el botón ingresar
    final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene el servicio de auth sin escuchar cambios de estado
    bool success = await auth.login(_dniCtrl.text.trim(), _passCtrl.text.trim()); // REM: Intenta iniciar sesión con los datos limpios (sin espacios)
    
    if (success) { // REM: Si el login fue exitoso (devuelve true)
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen())); // REM: Reemplaza esta pantalla por el Menú Principal (no se puede volver atrás con el botón de retroceso)
    } else { // REM: Si el login falló (devuelve false)
      ScaffoldMessenger.of(context).showSnackBar( // REM: Muestra un mensaje emergente en la parte inferior
        SnackBar(content: Text('DNI o Contraseña incorrectos'), backgroundColor: Colors.red) // REM: Texto de error con fondo rojo
      );
    }
  }

  @override
  Widget build(BuildContext context) { // REM: Método que construye la interfaz visual de la pantalla
    return Scaffold( // REM: Estructura básica de una pantalla en Flutter
      backgroundColor: Colors.black, // REM: Fondo negro absoluto (Estilo Troglodita)
      body: Center( // REM: Centra todo el contenido horizontal y verticalmente
        child: Padding( // REM: Añade espacio interno para que no pegue a los bordes
          padding: EdgeInsets.all(30), // REM: 30 píxeles de margen en todos los lados
          child: Column( // REM: Organiza los elementos hijos en una columna vertical
            mainAxisAlignment: MainAxisAlignment.center, // REM: Centra los elementos verticalmente en el espacio disponible
            children: [
              Text( // REM: Título principal de la aplicación
                'DESAYUNOS EL TONEL', 
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 28, fontWeight: FontWeight.bold) // REM: Texto blanco, fuente Courier, grande y negrita
              ),
              SizedBox(height: 40), // REM: Espacio vacío vertical de 40 píxeles
              TextField( // REM: Campo de entrada para el DNI
                controller: _dniCtrl, // REM: Vincula este campo al controlador _dniCtrl
                keyboardType: TextInputType.number, // REM: Muestra el teclado numérico del celular
                decoration: InputDecoration(
                  labelText: 'DNI', // REM: Etiqueta flotante
                  labelStyle: TextStyle(color: Colors.yellow), // REM: Color amarillo para la etiqueta
                  border: OutlineInputBorder() // REM: Borde rectangular alrededor del campo
                ), 
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew') // REM: Texto escrito en blanco y fuente Courier
              ),
              SizedBox(height: 20), // REM: Espacio vacío vertical de 20 píxeles
              TextField( // REM: Campo de entrada para la contraseña
                controller: _passCtrl, // REM: Vincula este campo al controlador _passCtrl
                obscureText: true, // REM: Oculta los caracteres escritos (puntos o asteriscos)
                decoration: InputDecoration(
                  labelText: 'CONTRASEÑA', // REM: Etiqueta flotante
                  labelStyle: TextStyle(color: Colors.yellow), // REM: Color amarillo para la etiqueta
                  border: OutlineInputBorder() // REM: Borde rectangular
                ), 
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew') // REM: Texto escrito en blanco y fuente Courier
              ),
              SizedBox(height: 30), // REM: Espacio vacío vertical de 30 píxeles
              ElevatedButton( // REM: Botón de acción principal
                onPressed: _login, // REM: Ejecuta la función _login al ser presionado
                child: Text('INGRESAR'), // REM: Texto dentro del botón
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50), // REM: Ancho infinito (ocupa todo el ancho) y alto de 50 píxeles
                  backgroundColor: Colors.yellow, // REM: Fondo amarillo
                  foregroundColor: Colors.black // REM: Texto negro
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}
