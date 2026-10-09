import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class ClientesScreen extends StatefulWidget {
  @override
  _ClientesScreenState createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Map<String, dynamic>> _clientes = [];
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
    final clientes = await db.consultar('clientes', orderBy: 'nombre ASC');
    setState(() {
      _clientes = clientes;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _clientes;
    final q = _busqueda.toLowerCase();
    return _clientes.where((c) {
      final nom = (c['nombre'] ?? '').toString().toLowerCase();
      final dni = (c['dni'] ?? '').toString().toLowerCase();
      final fono = (c['fono'] ?? '').toString().toLowerCase();
      return nom.contains(q) || dni.contains(q) || fono.contains(q);
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
      await db.actualizar('clientes', {'id': id, 'activo': 0});
      _cargarTodo();
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? cliente}) async {
    final nombreCtrl = TextEditingController(text: cliente?['nombre'] ?? '');
    final dniCtrl = TextEditingController(text: cliente?['dni'] ?? '');
    final fonoCtrl = TextEditingController(text: cliente?['fono'] ?? '');
    final direccionCtrl = TextEditingController(text: cliente?['direccion'] ?? '');
    final esEdicion = cliente != null;

    if (!mounted) return;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          esEdicion ? 'EDITAR CLIENTE' : 'NUEVO CLIENTE',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: InputDecoration(labelText: 'Nombre completo'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: dniCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'DNI (opcional)'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: fonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Teléfono (opcional)'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: direccionCtrl,
                decoration: InputDecoration(labelText: 'Dirección (opcional)'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
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
      if (nombreCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red),
        );
        return;
      }
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final data = {
        'nombre': nombreCtrl.text.trim(),
        'dni': dniCtrl.text.trim(),
        'fono': fonoCtrl.text.trim(),
        'direccion': direccionCtrl.text.trim(),
        'activo': 1,
      };
      try {
        if (esEdicion) {
          data['id'] = cliente['id'];
          await db.actualizar('clientes', data);
        } else {
          await db.insertar('clientes', data);
        }
        _cargarTodo();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Scaffold(
      appBar: AppBar(
        title: Text('CLIENTES (${filtrados.length})'),
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
                hintText: 'Buscar por nombre, DNI o teléfono...',
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
                        child: Text('Sin clientes',
                            style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew')),
                      )
                    : ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) {
                          final c = filtrados[i];
                          final activo = (c['activo'] ?? 1) == 1;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: activo ? Colors.yellow : Colors.grey,
                              child: Icon(Icons.person, color: Colors.black, size: 20),
                            ),
                            title: Text(
                              c['nombre'] ?? '',
                              style: TextStyle(
                                color: activo ? Colors.white : Colors.white38,
                                fontFamily: 'CourierNew',
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'DNI: ${c['dni'] ?? '-'} · Fono: ${c['fono'] ?? '-'}',
                              style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.yellow, size: 20),
                                  onPressed: () => _abrirFormulario(cliente: c),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _eliminar(c['id'] as int, c['nombre'] ?? ''),
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