import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para inyección de dependencias
import 'dart:async'; // REM: Librería para manejo de temporizadores (inactividad)
import 'services/database_helper.dart'; // REM: Servicio de base de datos local
import 'services/auth_service.dart'; // REM: Servicio de autenticación de usuarios
import 'screens/login_screen.dart'; // REM: Pantalla inicial de acceso

void main() { // REM: Punto de entrada absoluto de la aplicación
  runApp( // REM: Inicia el árbol de widgets de Flutter
    MultiProvider( // REM: Contenedor que provee servicios a toda la app
      providers: [ // REM: Lista de servicios disponibles globalmente
        ChangeNotifierProvider(create: (_) => DatabaseHelper()), // REM: Instancia única de Base de Datos
        ChangeNotifierProvider(create: (_) => AuthService(DatabaseHelper())), // REM: Instancia de Auth vinculada a DB
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
        primaryColor: Color(0xFFD32F2F), // REM: Rojo corporativo
