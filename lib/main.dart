import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'services/database_helper.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

final ValueNotifier<String?> zoneError = ValueNotifier<String?>(null);

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    ErrorWidget.builder = (FlutterErrorDetails d) => ErrorPanel(details: d);

    FlutterError.onError = (FlutterErrorDetails d) {
      FlutterError.presentError(d);
    };

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
    zoneError.value = '$error\n\n$stack';
  });
}

class ErrorPanel extends StatelessWidget {
  final FlutterErrorDetails details;
  const ErrorPanel({Key? key, required this.details}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF121212),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ERROR INTERNO — EL TONEL',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Copia este texto y envíalo al soporte.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        details.exceptionAsString(),
                        style: const TextStyle(
                          color: Color(0xFFFFC107),
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
        fontFamily: 'Roboto',
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Roboto'),
          hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'Roboto'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2),
          ),
        ),
      ),
      home: ValueListenableBuilder<String?>(
        valueListenable: zoneError,
        builder: (context, err, _) {
          if (err != null) {
            return ErrorPanel(details: FlutterErrorDetails(exception: err));
          }
          return const InactivityWrapper(child: LoginScreen());
        },
      ),
    );
  }
}

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  const InactivityWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;
  int _minutosInactividad = 10;
  bool _configCargada = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final db = context.read<DatabaseHelper>();
      final valor = await db.getParametro('inactividad_minutos');
      if (valor != null) {
        final mins = int.tryParse(valor);
        if (mins != null && mins > 0) {
          _minutosInactividad = mins;
        }
      }
    } catch (_) {
      // Si falla, usar el default de 10 minutos
    }
    setState(() => _configCargada = true);
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(minutes: _minutosInactividad), () {
      if (mounted) {
        final auth = Provider.of<AuthService>(context, listen: false);
        auth.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_configCargada) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
      );
    }
    return GestureDetector(
      onTap: _resetTimer,
      onPanDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}