import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class PersonalScreen extends StatefulWidget {
  @override
  _PersonalScreenState createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  List<Map<String, dynamic>> _personal = [];
  List<Map<String, dynamic>> _puntos = [];
  bool _cargando = true;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final personal = await db.consultar('personal', orderBy: 'apellidos ASC');
    final puntos = await db.getPuntosVenta();
    setState(() {
      _personal = personal;
      _puntos = puntos;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _personal;
    final q = _busqueda.toLowerCase();
    return _personal.where((p) {
      final ape = (p['apellidos'] ?? '').toString().toLowerCase();
      final nom = (p['nombres'] ?? '').toString().toLowerCase();
      final dni = (p['dni'] ?? '').toString().toLowerCase();
      final rol = (p['rol'] ?? '').toString().toLowerCase();
      return ape.contains(q) || nom.contains(q) || dni.contains(q) || rol.contains(q);
    }).toList();
  }

  Future<void> _eliminar(int id, String nombre) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('¿Desactivar?',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew')),
        content: Text('Se desactivará "$nombre"',
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
    if (conf == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.actualizar('personal', {'id': id, 'activo': 0});
      _cargarTodo();
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? persona}) async {
    final apellidosCtrl = TextEditingController(text: persona?['apellidos'] ?? '');
    final nombresCtrl = TextEditingController(text: persona?['nombres'] ?? '');
    final dniCtrl = TextEditingController(text: persona?['dni'] ?? '');
    final fonoCtrl = TextEditingController(text: persona?['fono'] ?? '');
    final passCtrl = TextEditingController(text: persona?['password'] ?? '');
    String rolSeleccionado = persona?['rol'] ?? 'VENDEDOR';
    int? puntoSeleccionado = persona?['punto_venta_id'] as int?;
    if (puntoSeleccionado == null && _puntos.isNotEmpty) {
      puntoSeleccionado = _puntos.first['id'] as int;
    }
    final esEdicion = persona != null;

    if (!mounted) return;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          esEdicion ? 'EDITAR PERSONA' : 'NUEVA PERSONA',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: apellidosCtrl,
                decoration: InputDecoration(labelText: 'Apellidos'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: nombresCtrl,
                decoration: InputDecoration(labelText: 'Nombres'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: dniCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'DNI (8 dígitos)'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: fonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Teléfono'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(labelText: 'Contraseña'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: rolSeleccionado,
                dropdownColor: Colors.black,
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                decoration: InputDecoration(labelText: 'Rol'),
                items: [
                  DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'VENDEDOR', child: Text('VENDEDOR', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => rolSeleccionado = v ?? 'VENDEDOR',
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: puntoSeleccionado,
                dropdownColor: Colors.black,
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                decoration: InputDecoration(labelText: 'Punto de venta'),
                items: _puntos.map<DropdownMenuItem<int>>((p) {
                  return DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text(
                      '${p['codigo']} - ${p['nombre']}',
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (v) => puntoSeleccionado = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('CANCELAR', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('GUARDAR', style: TextStyle(color: Colors.yellow))),
        ],
      ),
    );

    if (guardar == true) {
      if (apellidosCtrl.text.trim().isEmpty || nombresCtrl.text.trim().isEmpty || dniCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete apellidos, nombres, DNI y contraseña'), backgroundColor: Colors.red),
        );
        return;
      }
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final data = {
        'apellidos': apellidosCtrl.text.trim(),
        'nombres': nombresCtrl.text.trim(),
        'dni': dniCtrl.text.trim(),
        'fono': fonoCtrl.text.trim(),
        'rol': rolSeleccionado,
        'password': passCtrl.text.trim(),
        'punto_venta_id': puntoSeleccionado,
        'activo': 1,
      };
      try {
        if (esEdicion) {
          data['id'] = persona['id'];
          await db.actualizar('personal', data);
        } else {
          await db.insertar('personal', data);
        }
        _cargarTodo();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nombrePunto(int? id) {
    if (id == null || id == 0) return 'BASE';
    final punto = _puntos.where((p) => p['id'] == id).toList();
    if (punto.isEmpty) return 'BASE';
    return punto.first['codigo'] ?? '?';
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Scaffold(
      appBar: AppBar(
        title: Text('PERSONAL (${filtrados.length})'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarTodo),
        ],
      ),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.yellow,
        onPressed: () => _abrirFormulario(),
        child: Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, DNI o rol...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: Colors.yellow),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13),
            ),
          ),
          Expanded(
            child: _cargando
                ? Center(child: CircularProgressIndicator(color: Colors.yellow))
                : filtrados.isEmpty
                    ? Center(
                        child: Text('Sin personal',
                            style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew')),
                      )
                    : ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) {
                          final p = filtrados[i];
                          final activo = (p['activo'] ?? 1) == 1;
                          final esAdmin = p['rol'] == 'ADMIN';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: activo
                                  ? (esAdmin ? Colors.orange : Colors.yellow)
                                  : Colors.grey,
                              child: Icon(
                                esAdmin ? Icons.shield : Icons.person,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${p['apellidos'] ?? ''}, ${p['nombres'] ?? ''}',
                              style: TextStyle(
                                color: activo ? Colors.white : Colors.white38,
                                fontFamily: 'CourierNew',
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'DNI: ${p['dni'] ?? ''} · ${p['rol'] ?? ''} · ${_nombrePunto(p['punto_venta_id'] as int?)}',
                              style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.yellow, size: 20),
                                  onPressed: () => _abrirFormulario(persona: p),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _eliminar(p['id'] as int, '${p['apellidos']}, ${p['nombres']}'),
                                ),
                              ],
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