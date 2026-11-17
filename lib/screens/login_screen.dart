import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _dniCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _cargando = false;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  String get _diaSemana {
    final dias = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
    return dias[DateTime.now().weekday - 1];
  }

  String get _horaActual {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  bool _estaEnHorario(String ini, String fin) {
    return _horaActual.compareTo(ini) >= 0 && _horaActual.compareTo(fin) <= 0;
  }

  void _mostrarDialogo(String