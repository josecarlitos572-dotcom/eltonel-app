import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/database_helper.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseHelper()),
        ChangeNotifierProvider(create: (context) => AuthService(context.read<DatabaseHelper>())),
      ],
      child: ElTonelApp(),
    ),
  );
}

class ElTonelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desayunos El Tonel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFD32F2F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD32F2F),
          secondary: Color(0xFFFFC107),
          surface: Color(0xFF1E1E1E),
        ),
        fontFamily: 'CourierNew',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'CourierNew',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'CourierNew'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'CourierNew'),
          hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'CourierNew'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2)),
        ),
      ),
      home: InactivityWrapper(child: LoginScreen()),
    );
  }
}

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  const InactivityWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _InactivityWrapperState createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 10), () {
      if (mounted) {
        final auth = Provider.of<AuthService>(context, listen: false);
        auth.logout();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimer,
      onPanStart: (_) => _resetTimer(),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}