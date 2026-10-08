import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class CategoriasGastoScreen extends StatefulWidget {
  @override
  _CategoriasGastoScreenState createState() => _CategoriasGastoScreenState();
}

class _CategoriasGastoScreenState extends State<CategoriasGastoScreen> {
  List<Map<String, dynamic>> _categorias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final data = await db.getCategoriasGasto();
    setState(() {
      _categorias = data;
      _cargando = false;
    });
  }

  Future<void> _editar({Map<String, dynamic>? categoria}) async {
    final nombreCtrl = TextEditingController(text: categoria?['nombre'] ?? '');
    final limiteCtrl = TextEditingController(
      text: categoria != null ? (categoria['limite_max'] ?? '').toString() : '',
    );
    final esEdicion = categoria != null;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          esEdicion ? 'EDITAR CATEGORÍA' : 'NUEVA CATEGORÍA',
          style: TextStyle(
            color: Colors.yellow,
            fontFamily: 'CourierNew',
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: InputDecoration(labelText: 'Nombre'),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: limiteCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Límite máximo S/'),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('GUARDAR', style: TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final data = {
        'nombre': nombreCtrl.text.trim(),
        'limite_max': double.tryParse(limiteCtrl.text) ?? 9999,
      };
      if (esEdicion) {
        data['id'] = categoria['id'];
        await db.actualizar('categorias_gasto', data);
      } else {
        await db.insertar('categorias_gasto', data);
      }
      _cargar();
    }
  }

  Future<void> _eliminar(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          '¿Eliminar?',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew'),
        ),
        content: Text(
          'Se desactivará "$nombre"',
          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('NO', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('SÍ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.actualizar('categorias_gasto', {'id': id, 'activo': 0});
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('CATEGORÍAS DE GASTO')),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.yellow,
        onPressed: () => _editar(),
        child: Icon(Icons.add, color: Colors.black),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.yellow))
          : ListView.builder(
              itemCount: _categorias.length,
              itemBuilder: (context, i) {
                final c = _categorias[i];
                final activo = (c['activo'] ?? 1) == 1;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: activo ? Colors.yellow : Colors.grey,
                    child: Icon(
                      Icons.receipt,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    c['nombre'] ?? '',
                    style: TextStyle(
                      color: activo ? Colors.white : Colors.white38,
                      fontFamily: 'CourierNew',
                    ),
                  ),
                  subtitle: Text(
                    'Límite: S/ ${(c['limite_max'] ?? 0).toString()} · ${activo ? "ACTIVO" : "INACTIVO"}',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'CourierNew',
                      fontSize: 11,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.yellow),
                        onPressed: () => _editar(categoria: c),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _eliminar(c['id'] as int, c['nombre'] ?? ''),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}