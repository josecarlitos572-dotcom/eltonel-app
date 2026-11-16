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

  void _mostrarDialogo(String titulo, String mensaje, Color colorTitulo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(titulo, style: TextStyle(color: colorTitulo, fontFamily: 'CourierNew', fontSize: 16)),
        content: Text(mensaje, style: const TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: Color(0xFFFFC107))),
          ),
        ],
      ),
    );
  }

  void _login() async {
    if (_dniCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _mostrarDialogo('FALTAN DATOS', 'Ingrese DNI y contraseña', Colors.orange);
      return;
    }

    setState(() => _cargando = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DatabaseHelper>(context, listen: false);

    bool success = await auth.login(_dniCtrl.text.trim(), _passCtrl.text.trim());

    if (!success) {
      setState(() => _cargando = false);
      _mostrarDialogo('ERROR', 'DNI o Contraseña incorrectos', Colors.red);
      return;
    }

    final usuario = auth.currentUser!;
    final rol = usuario['rol'] as String?;

    if (rol == 'VENDEDOR') {
      if (_diaSemana == 'dom') {
        auth.logout();
        setState(() => _cargando = false);
        _mostrarDialogo('HOY NO HAY LABOR', 'Los domingos el negocio no opera.\n\nVuelve el lunes.', Colors.orange);
        return;
      }

      if (!_estaEnHorario('03:00', '11:00')) {
        auth.logout();
        setState(() => _cargando = false);
        _mostrarDialogo('FUERA DE HORARIO', 'El horario de operación es de 03:00 a 11:00.\n\nHora actual: $_horaActual', Colors.red);
        return;
      }

      final asignaciones = await db.consultar(
        'asignaciones_diarias',
        where: 'usuario_id = ? AND fecha = ? AND estado = ?',
        whereArgs: [usuario['id'], _hoy, 'ACTIVO'],
      );

      if (asignaciones.isEmpty) {
        auth.logout();
        setState(() => _cargando = false);
        _mostrarDialogo('SIN ASIGNACIÓN', 'No estás asignado para trabajar hoy.\n\nContacta al administrador.', Colors.red);
        return;
      }
    }

    setState(() => _cargando = false);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO SIMULADO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC107), width: 3),
                ),
                child: const Icon(Icons.breakfast_dining, size: 60, color: Color(0xFFFFC107)),
              ),
              const SizedBox(height: 20),
              const Text(
                'DESAYUNOS EL TONEL',
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistema de Gestión',
                style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 12),
              ),
              const SizedBox(height: 50),
              TextField(
                controller: _dniCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'DNI'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'CONTRASEÑA'),
              ),
              const SizedBox(height: 40),
              _cargando
                  ? const CircularProgressIndicator(color: Color(0xFFFFC107))
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text('INGRESAR'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}