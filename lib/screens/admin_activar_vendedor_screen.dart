import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class AdminActivarVendedorScreen extends StatefulWidget {
  @override
  _AdminActivarVendedorScreenState createState() => _AdminActivarVendedorScreenState();
}

class _AdminActivarVendedorScreenState extends State<AdminActivarVendedorScreen> {
  List<Map<String, dynamic>> _personal = [];
  List<Map<String, dynamic>> _puntos = [];
  List<Map<String, dynamic>> _asignacionesHoy = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  String get _hoy {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final personal = await db.consultar('personal',
        where: 'activo = 1', orderBy: 'apellidos ASC');
    final puntos = await db.getPuntosVenta();
    final asignaciones = await db.consultar('asignaciones_diarias',
        where: 'fecha = ?', whereArgs: [_hoy], orderBy: 'id DESC');

    setState(() {
      _personal = personal;
      _puntos = puntos;
      _asignacionesHoy = asignaciones;
      _cargando = false;
    });
  }

  bool _yaAsignado(int usuarioId) {
    return _asignacionesHoy.any((a) => a['usuario_id'] == usuarioId && a['estado'] == 'ACTIVO');
  }

  Future<void> _activar(Map<String, dynamic> persona) async {
    if (_yaAsignado(persona['id'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya está activo hoy'), backgroundColor: Colors.orange),
      );
      return;
    }

    int? puntoSeleccionado = persona['punto_venta_id'] as int?;
    if (puntoSeleccionado == null || puntoSeleccionado == 0) {
      puntoSeleccionado = _puntos.isNotEmpty ? _puntos.first['id'] as int : null;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        int? seleccion = puntoSeleccionado;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: Text(
                'ACTIVAR: ${persona['apellidos'] ?? ''}',
                style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 14),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Punto de venta para hoy:',
                      style: TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 12)),
                  SizedBox(height: 10),
                  ..._puntos.map((p) {
                    final id = p['id'] as int;
                    return RadioListTile<int>(
                      value: id,
                      groupValue: seleccion,
                      onChanged: (v) => setStateDialog(() => seleccion = v),
                      title: Text(
                        '${p['codigo']} - ${p['nombre']}',
                        style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                      ),
                      activeColor: Colors.yellow,
                    );
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('CANCELAR', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () {
                    puntoSeleccionado = seleccion;
                    Navigator.pop(ctx, true);
                  },
                  child: Text('ACTIVAR', style: TextStyle(color: Colors.yellow)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar == true && puntoSeleccionado != null) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final ahora = DateTime.now().toIso8601String();
      try {
        await db.insertar('asignaciones_diarias', {
          'fecha': _hoy,
          'usuario_id': persona['id'],
          'punto_venta_id': puntoSeleccionado,
          'hora_inicio': ahora,
          'estado': 'ACTIVO',
          'activado_por': auth.currentUser?['id'],
        });
        _cargarTodo();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendedor activado'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cerrarAsignacion(int idAsignacion, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('¿Cerrar asignación?',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew')),
        content: Text('Se cerrará el turno de "$nombre"',
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NO', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('SÍ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.actualizar('asignaciones_diarias', {
        'id': idAsignacion,
        'estado': 'CERRADO',
        'hora_fin': DateTime.now().toIso8601String(),
      });
      _cargarTodo();
    }
  }

  String _nombrePunto(int? id) {
    if (id == null) return '?';
    final p = _puntos.where((e) => e['id'] == id).toList();
    if (p.isEmpty) return '?';
    return '${p.first['codigo']} - ${p.first['nombre']}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ACTIVAR VENDEDOR'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarTodo),
        ],
      ),
      backgroundColor: Colors.black,
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.yellow))
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'HOY: $_hoy',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontFamily: 'CourierNew',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _personal.length,
                    itemBuilder: (context, i) {
                      final p = _personal[i];
                      final asignado = _yaAsignado(p['id'] as int);
                      final asignacion = asignado
                          ? _asignacionesHoy.firstWhere((a) =>
                              a['usuario_id'] == p['id'] && a['estado'] == 'ACTIVO')
                          : null;
                      final esAdmin = p['rol'] == 'ADMIN';

                      return Card(
                        color: Color(0xFF1A1A1A),
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: asignado
                                ? Colors.green
                                : (esAdmin ? Colors.orange : Colors.grey),
                            child: Icon(
                              asignado ? Icons.check : (esAdmin ? Icons.shield : Icons.person),
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${p['apellidos'] ?? ''}, ${p['nombres'] ?? ''}',
                            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13),
                          ),
                          subtitle: Text(
                            asignado
                                ? 'Hoy en: ${_nombrePunto(asignacion?['punto_venta_id'] as int?)}'
                                : '${p['rol'] ?? ''} · Sin asignar hoy',
                            style: TextStyle(
                              color: asignado ? Colors.green : Colors.white54,
                              fontFamily: 'CourierNew',
                              fontSize: 11,
                            ),
                          ),
                          trailing: asignado
                              ? IconButton(
                                  icon: Icon(Icons.lock, color: Colors.red),
                                  onPressed: () => _cerrarAsignacion(
                                      asignacion!['id'] as int,
                                      '${p['apellidos']}, ${p['nombres']}'),
                                )
                              : IconButton(
                                  icon: Icon(Icons.play_arrow, color: Colors.yellow),
                                  onPressed: () => _activar(p),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}