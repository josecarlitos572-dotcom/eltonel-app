import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para inyección de dependencias
import 'services/database_helper.dart'; // REM: Servicio de base de datos local SQLite
import 'services/auth_service.dart'; // REM: Servicio de autenticación y sesiones
import 'screens/login_screen.dart'; // REM: Pantalla de acceso inicial

void main() { // REM: Punto de entrada absoluto de la aplicación
  runApp( // REM: Inicia el árbol de widgets de Flutter
    MultiProvider( // REM: Contenedor que provee servicios a toda la app
      providers: [ // REM: Lista de servicios globales
        ChangeNotifierProvider(create: (_) => DatabaseHelper()), // REM: Instancia única de Base de Datos
        ChangeNotifierProxyProvider<DatabaseHelper, AuthService>( // REM: AuthService depende de DatabaseHelper
          create: (_) => AuthService(Provider.of<DatabaseHelper>(_, listen: false)), // REM: Crea Auth con DB
          update: (_, dbHelper, authService) => authService ?? AuthService(dbHelper), // REM: Actualiza si cambia DB
        ),
      ],
      child: ElTonelApp(), // REM: Widget raíz de la aplicación
    ),
  );
}

class ElTonelApp extends StatelessWidget { // REM: Configuración global de la app
  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz raíz
    return MaterialApp( // REM: Componente principal de navegación y tema
      title: 'Desayunos El Tonel', // REM: Título interno del sistema
      debugShowCheckedModeBanner: false, // REM: Oculta la etiqueta "DEBUG" en esquina
      theme: ThemeData( // REM: Definición del estilo visual global
        primaryColor: Color(0xFFD32F2F), // REM: Rojo corporativo (opcional, usado en detalles)
        scaffoldBackgroundColor: Colors.black, // REM: Fondo negro absoluto para todas las pantallas
        textTheme: TextTheme( // REM: Tipografía global
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 16), // REM: Texto cuerpo blanco Courier
          titleLarge: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 22, fontWeight: FontWeight.bold), // REM: Títulos grandes
        ),
        elevatedButtonTheme: ElevatedButtonThemeData( // REM: Estilo global de botones
          style: ElevatedButton.styleFrom( // REM: Configuración de estilo
            backgroundColor: Colors.yellow, // REM: Botones amarillos señalética
            foregroundColor: Colors.black, // REM: Texto negro para contraste
            textStyle: TextStyle(fontFamily: 'CourierNew', fontSize: 18, fontWeight: FontWeight.bold), // REM: Fuente botón
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20), // REM: Espaciado interno botón
          ),
        ),
      ),
      home: InactivityWrapper(child: LoginScreen()), // REM: Pantalla inicial envuelta en seguridad
    );
  }
}

class InactivityWrapper extends StatefulWidget { // REM: Wrapper que detecta inactividad del usuario
  final Widget child; // REM: Widget hijo (la app real)
  InactivityWrapper({required this.child}); // REM: Constructor obligatorio
  
  @override
  _InactivityWrapperState createState() => _InactivityWrapperState(); // REM: Crea estado del wrapper
}

class _InactivityWrapperState extends State<InactivityWrapper> { // REM: Lógica de temporizador
  Timer? _timer; // REM: Variable para el contador de tiempo
  
  @override
  void initState() { // REM: Al iniciar el wrapper
    super.initState(); // REM: Llama inicialización padre
    _resetTimer(); // REM: Inicia o reinicia el contador
  }

  void _resetTimer() { // REM: Función para reiniciar cuenta regresiva
    _timer?.cancel(); // REM: Cancela timer anterior si existe
    _timer = Timer(Duration(minutes: 5), () { // REM: Programa nuevo timer de 5 minutos
      if (mounted) { // REM: Verifica que el widget siga activo en memoria
        final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio Auth
        auth.logout(); // REM: Cierra sesión automáticamente
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen())); // REM: Vuelve al login
      }
    });
  }

  @override
  Widget build(BuildContext context) { // REM: Construye el wrapper
    return GestureDetector( // REM: Detector de gestos táctiles
      onTap: _resetTimer, // REM: Al tocar pantalla, reinicia timer
      onPanStart: (_) => _resetTimer(), // REM: Al deslizar dedo, reinicia timer
      child: widget.child, // REM: Muestra la app hija (Login/Home)
    );
  }

  @override
  void dispose() { // REM: Al destruir el widget
    _timer?.cancel(); // REM: Limpia el timer para evitar fugas de memoria
    super.dispose(); // REM: Llama limpieza padre
  }
}
