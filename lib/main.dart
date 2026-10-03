import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/database_helper.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DatabaseHelper(),
      child: ElTonelApp(),
    ),
  );
}

class ElTonelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desayunos El Tonel',
      theme: ThemeData(
        primaryColor: Color(0xFFD32F2F),
        scaffoldBackgroundColor: Colors.black,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 18),
          titleLarge: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black,
            textStyle: TextStyle(fontFamily: 'CourierNew', fontSize: 20, fontWeight: FontWeight.bold),
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          ),
        ),
      ),
      home: InactivityWrapper(child: LoginScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  InactivityWrapper({required this.child});
  @override
  _InactivityWrapperState createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    _resetTimer();
  }
  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(minutes: 5), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
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
  void dispose() { _timer.cancel(); super.dispose(); }
}
