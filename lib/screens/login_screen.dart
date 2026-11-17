// ============================================================
// login_screen.dart — Acceso El Tonel (v1.1)
// Cambio: logo real desde assets con fallback a ícono.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _dniCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _cargando = false;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];
  String get _diaSemana {
    const dias = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
    return dias[DateTime.now().weekday - 1];
  }
  String get _horaActual {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
  bool _estaEnHorario(String ini, String fin) => _horaActual.compareTo(ini) >= 0 && _horaActual.compareTo(fin) <= 0;

  void _mostrarDialogo(String titulo, String mensaje, Color colorTitulo) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(titulo, style: TextStyle(color: colorTitulo, fontSize: 16)),
      content: Text(mensaje, style: const TextStyle(color: Colors.white, fontSize: 13)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ENTENDIDO', style: TextStyle(color: Color(0xFFFFC107))))],
    ));
  }

  Future<void> _login() async {
    if (_dniCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _mostrarDialogo('FALTAN DATOS', 'Ingrese DNI y contraseña', Colors.orange); return;
    }
    setState(() => _cargando = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final bool success = await auth.login(_dniCtrl.text.trim(), _passCtrl.text.trim());
    if (!success) {
      setState(() => _cargando = false);
      _mostrarDialogo('ERROR', 'DNI o Contraseña incorrectos', Colors.red); return;
    }
    final usuario = auth.currentUser!;
    final rol = usuario['rol'] as String?;
    if (rol == 'VENDEDOR') {
      if (_diaSemana == 'dom') { auth.logout(); setState(() => _cargando = false); _mostrarDialogo('HOY NO HAY LABOR', 'Los domingos el negocio no opera.\n\nVuelve el lunes.', Colors.orange); return; }
      if (!_estaEnHorario('03:00', '11:00')) { auth.logout(); setState(() => _cargando = false); _mostrarDialogo('FUERA DE HORARIO', 'El horario es de 03:00 a 11:00.\n\nHora actual: $_horaActual', Colors.red); return; }
      final asignaciones = await db.consultar('asignaciones_diarias', where: 'usuario_id = ? AND fecha = ? AND estado = ?', whereArgs: [usuario['id'], _hoy, 'ACTIVO']);
      if (asignaciones.isEmpty) { auth.logout(); setState(() => _cargando = false); _mostrarDialogo('SIN ASIGNACIÓN', 'No estás asignado para hoy.\n\nContacta al administrador.', Colors.red); return; }
    }
    setState(() => _cargando = false);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  @override
  void dispose() { _dniCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A0E0E), Color(0xFF121212)])),
      child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFC107), width: 3), boxShadow: const [BoxShadow(color: Color(0x66FFC107), blurRadius: 24, spreadRadius: 2)]),
          // ✅ Logo real del repositorio (assets/logo/eltonel_logo.png)
          child: Image.asset('assets/logo/eltonel_logo.png', width: 64, height: 64, errorBuilder: (_, __, ___) => const Icon(Icons.breakfast_dining, size: 64, color: Color(0xFFFFC107)))),
        const SizedBox(height: 22),
        const Text('DESAYUNOS EL TONEL', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('Sistema de Gestión · v1.1', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 44),
        TextField(controller: _dniCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'DNI')),
        const SizedBox(height: 18),
        TextField(controller: _passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'CONTRASEÑA')),
        const SizedBox(height: 36),
        _cargando ? const CircularProgressIndicator(color: Color(0xFFFFC107)) : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _login, child: const Text('INGRESAR'))),
      ]))))));
  }
}