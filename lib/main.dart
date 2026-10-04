import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para inyección de dependencias
import 'dart:async'; // REM: Librería para manejo de temporizadores (inactividad)
import 'services/database_helper.dart'; // REM: Servicio de base de datos local
import 'services/auth_service.dart'; // REM: Servicio de autenticación de usuarios
import 'screens/login_screen.dart'; // REM: Pantalla inicial de acceso

void main() { // REM: Punto de entrada absoluto de la aplicación
  // ✅ CAMBIO 1: Forzar a Flutter a mostrar el error en pantalla (modo release)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Text(
              'ERROR DETECTADO:\n\n${details.exception}\n\n${details.stack ?? ""}',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  };

  runApp( // REM: Inicia el árbol de widgets de Flutter
    MultiProvider( // REM: Contenedor que provee servicios a toda la app
      providers: [ // REM: Lista de servicios disponibles globalmente
        ChangeNotifierProvider(create: (_) => DatabaseHelper()), // REM: Instancia única de Base de Datos
        // ✅ CAMBIO 2: Reusar la MISMA instancia de DatabaseHelper en AuthService
        ChangeNotifierProvider(
          create: (context) => AuthService(context.read<DatabaseHelper>()),
        ),
      ],
      child: ElTonelApp(), // REM: Widget raíz de la aplicación
    ),
  );
}

class ElTonelApp extends StatelessWidget { // REM: Definición de la aplicación principal
  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz base
    return MaterialApp( // REM: Configura el entorno Material Design
      title: 'Desayunos El Tonel', // REM: Nombre interno de la app
      debugShowCheckedModeBanner: false, // REM: Oculta la etiqueta "DEBUG" en esquina superior
      theme: ThemeData( // REM: Configuración del tema visual global
        primaryColor: Color(0xFFD32F2F), // REM: Rojo corporativo para acentos
        scaffoldBackgroundColor: Colors.black, // REM: Fondo negro absoluto (Estilo Troglodita)
        fontFamily: 'CourierNew', // REM: Fuente global Courier New para toda la app
        textTheme: TextTheme( // REM: Tipografía personalizada
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16), // REM: Texto cuerpo blanco
          bodyMedium: TextStyle(color: Colors.white, fontSize: 14), // REM: Texto secundario blanco
          bodySmall: TextStyle(color: Colors.white70, fontSize: 12), // REM: Texto auxiliar tenue
          titleLarge: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), // REM: Títulos blancos negrita
          titleMedium: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), // REM: Subtítulos
        ),
        appBarTheme: AppBarTheme( // REM: Estilo global de AppBars
          backgroundColor: Color(0xFFD32F2F), // REM: Fondo rojo corporativo
          foregroundColor: Colors.white, // REM: Texto e iconos blancos
          titleTextStyle: TextStyle( // REM: Estilo del título del AppBar
            color: Colors.white, // REM: Texto blanco
            fontFamily: 'CourierNew', // REM: Courier New
            fontSize: 20, // REM: Tamaño legible
            fontWeight: FontWeight.bold, // REM: Negrita
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData( // REM: Estilo global de botones
          style: ElevatedButton.styleFrom( // REM: Configuración de estilo
            backgroundColor: Colors.yellow, // REM: Fondo amarillo señalética
            foregroundColor: Colors.black, // REM: Texto negro para contraste máximo
            textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // REM: Fuente heredada + negrita
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20), // REM: Espaciado interno cómodo
          ),
        ),
        inputDecorationTheme: InputDecorationTheme( // REM: Estilo global de campos de texto
          labelStyle: TextStyle(color: Colors.white70), // REM: Etiquetas tenues
          hintStyle: TextStyle(color: Colors.white38), // REM: Placeholders muy tenues
          enabledBorder: OutlineInputBorder( // REM: Borde cuando no está enfocado
            borderSide: BorderSide(color: Colors.white54), // REM: Gris claro
          ),
          focusedBorder: OutlineInputBorder( // REM: Borde cuando está enfocado
            borderSide: BorderSide(color: Colors.yellow, width: 2), // REM: Amarillo resaltado
          ),
        ),
      ),
      home: InactivityWrapper(child: LoginScreen()), // REM: Pantalla inicial envuelta en seguridad por inactividad
    );
  }
}

class InactivityWrapper extends StatefulWidget { // REM: Widget que detecta falta de uso
  final Widget child; // REM: Widget hijo (la app real)
  InactivityWrapper({required this.child}); // REM: Constructor que recibe el hijo obligatorio

  @override
  _InactivityWrapperState createState() => _InactivityWrapperState(); // REM: Crea el estado del wrapper
}

class _InactivityWrapperState extends State<InactivityWrapper> { // REM: Lógica de detección de inactividad
  Timer? _timer; // ✅ CAMBIO 3: Nullable en vez de "late" (evita LateInitializationError)
  
  @override
  void initState() { // REM: Se ejecuta al montar el widget
    super.initState(); // REM: Llama al init del padre
    _resetTimer(); // REM: Inicia o reinicia el contador de seguridad
  }

  void _resetTimer() { // REM: Reinicia el conteo de 5 minutos
    _timer?.cancel(); // REM: Cancela cualquier temporizador previo activo (si existe)
    _timer = Timer(Duration(minutes: 5), () { // REM: Programa nuevo timer de 5 min
      if (mounted) { // REM: Verifica que el widget siga existiendo en pantalla
        final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio Auth sin escuchar cambios
        auth.logout(); // REM: Cierra sesión forzadamente por seguridad
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen())); // REM: Regresa al login
      }
    });
  }

  @override
  Widget build(BuildContext context) { // REM: Construye el wrapper invisible
    return GestureDetector( // REM: Detector de gestos táctiles en toda la pantalla
      onTap: _resetTimer, // REM: Al tocar, reinicia el timer de 5 min
      onPanStart: (_) => _resetTimer(), // REM: Al deslizar dedo, también reinicia timer
      child: widget.child, // REM: Muestra la app real como hija
    );
  }

  @override
  void dispose() { // REM: Limpieza al destruir el widget
    _timer?.cancel(); // REM: Detiene el timer (con ?. por si aún no se ha creado)
    super.dispose(); // REM: Llama al dispose del padre
  }
}
