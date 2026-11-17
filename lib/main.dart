// ============================================================
// main.dart — Entrada de "Desayunos El Tonel"
// Arranque blindado: nunca deja pantalla blanca.
// Cualquier error de build se pinta en pantalla como texto.
// ============================================================

import 'dart:async';                          // runZonedGuarded + Timer
import 'package:flutter/material.dart';      // Widgets y tema
import 'package:flutter/foundation.dart';    // FlutterError / FlutterErrorDetails
import 'package:provider/provider.dart';     // Inyección de estado
import 'services/database_helper.dart';      // Capa de base de datos local
import 'services/auth_service.dart';         // Capa de autenticación
import 'screens/login_screen.dart';          // Primera pantalla

// Notifier global para errores asíncronos (zona) visibles en pantalla.
final ValueNotifier<String?> zoneError = ValueNotifier<String?>(null);

void main() {
  // Zona protegida: captura errores asíncronos no manejados.
  runZonedGuarded<Future<void>>(() async {
    // Despierta el motor Flutter antes de tocar plugins (sqflite, etc.).
    WidgetsFlutterBinding.ensureInitialized();

    // En release, sustituye el lienzo blanco por un panel de error legible.
    ErrorWidget.builder = (FlutterErrorDetails d) => ErrorPanel(details: d);

    // Registra errores de framework sin romper la UI.
    FlutterError.onError = (FlutterErrorDetails d) {
      FlutterError.presentError(d);          // Mantiene el reporte estándar
    };

    // Lanza la app con sus providers de estado.
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DatabaseHelper()),
          ChangeNotifierProvider(
            create: (ctx) => AuthService(ctx.read<DatabaseHelper>()),
          ),
        ],
        child: const ElTonelApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // Publica el error asíncrono para que la UI lo muestre.
    zoneError.value = '$error\n\n$stack';
  });
}

// Panel de error visible en CUALQUIER modo (debug y release).
class ErrorPanel extends StatelessWidget {
  final FlutterErrorDetails details;        // Detalle del fallo de build
  const ErrorPanel({Key? key, required this.details}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,     // Necesario fuera de MaterialApp
      child: Material(
        color: const Color(0xFF121212),     // Fondo oscuro de la marca
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ERROR INTERNO — EL TONEL',
                  style: TextStyle(
                    color: Color(0xFFFF5252),          // Rojo de peligro
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Copia este texto (mantén presionado) y envíalo.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,             // Scroll visible propio
                    child: SingleChildScrollView(
                      child: SelectableText(
                        details.exceptionAsString(),   // Mensaje real del error
                        style: const TextStyle(
                          color: Color(0xFFFFC107),    // Ámbar de acento
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Raíz visual de la aplicación.
class ElTonelApp extends StatelessWidget {
  const ElTonelApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desayunos El Tonel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFD32F2F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD32F2F),
          secondary: Color(0xFFFFC107),
          surface: Color(0xFF1E1E1E),
        ),
        fontFamily: 'Roboto',                 // Fuente nativa, sin assets
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Roboto'),
          hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'Roboto'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2)),
        ),
      ),
      // Escucha errores de zona y los muestra encima de todo.
      home: ValueListenableBuilder<String?>(
        valueListenable: zoneError,
        builder: (context, err, _) {
          if (err != null) {
            return ErrorPanel(
              details: FlutterErrorDetails(exception: err),
            );
          }
          return InactivityWrapper(child: LoginScreen());
        },
      ),
    );
  }
}

// Cierra sesión tras 10 minutos sin interacción.
class InactivityWrapper extends StatefulWidget {
  final Widget child;
  const InactivityWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;                            // Temporizador de inactividad

  @override
  void initState() {
    super.initState();
    _resetTimer();                          // Arranca el conteo
  }

  void _resetTimer() {
    _timer?.cancel();                       // Cancela el anterior
    _timer = Timer(const Duration(minutes: 10), () {
      if (mounted) {
        final auth = Provider.of<AuthService>(context, listen: false);
        auth.logout();                      // Limpia sesión
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimer,                   // Cualquier toque reinicia
      onPanDown: (_) => _resetTimer(),      // Cualquier arrastre reinicia
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();                       // Libera el temporizador
    super.dispose();
  }
}