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
        backgroundColor: Colors.black,
        title: Text(titulo,
            style: TextStyle(color: colorTitulo, fontFamily: 'CourierNew', fontSize: 16)),
        content: Text(mensaje,
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ENTENDIDO', style: TextStyle(color: Colors.yellow)),
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
        _mostrarDialogo(
          'HOY NO HAY LABOR',
          'Los domingos el negocio no opera.\n\nVuelve el lunes.',
          Colors.orange,
        );
        return;
      }

      if (!_estaEnHorario('03:00', '11:00')) {
        auth.logout();
        setState(() => _cargando = false);
        _mostrarDialogo(
          'FUERA DE HORARIO',
          'El horario de operación es de 03:00 a 11:00.\n\nHora actual: $_horaActual',
          Colors.red,
        );
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
        _mostrarDialogo(
          'SIN ASIGNACIÓN',
          'No estás asignado para trabajar hoy.\n\nContacta al administrador.',
          Colors.red,
        );
        return;
      }
    }

    setState(() => _cargando = false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'DESAYUNOS EL TONEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'CourierNew',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'CourierNew',
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 40),
                TextField(
                  controller: _dniCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'DNI',
                    labelStyle: TextStyle(color: Colors.yellow),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'CONTRASEÑA',
                    labelStyle: TextStyle(color: Colors.yellow),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                ),
                SizedBox(height: 30),
                _cargando
                    ? CircularProgressIndicator(color: Colors.yellow)
                    : ElevatedButton(
                        onPressed: _login,
                        child: Text('INGRESAR'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
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