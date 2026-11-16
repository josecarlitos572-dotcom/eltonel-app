import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class CategoriasProductoScreen extends StatefulWidget {
  @override
  _CategoriasProductoScreenState createState() => _CategoriasProductoScreenState();
}

class _CategoriasProductoScreenState extends State<CategoriasProductoScreen> {
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
    final data = await db.consultar('categorias_producto', orderBy: 'orden ASC');
    setState(() {
      _categorias = data;
      _cargando = false;
    });
  }

  Future<void> _editar({Map<String, dynamic>? categoria}) async {
    final nombreCtrl = TextEditingController(text: categoria?['nombre'] ?? '');
    final abrevCtrl = TextEditingController(text: categoria?['abreviatura'] ?? '');
    final esEdicion = categoria != null;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          esEdicion ? 'EDITAR CATEGORÍA' : 'NUEVA CATEGORÍA',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
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
              controller: abrevCtrl,
              maxLength: 5,
              decoration: InputDecoration(labelText: 'Abreviatura'),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
          ],
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

    if (resultado == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final Map<String, dynamic> data = {
        'nombre': nombreCtrl.text.trim(),
        'abreviatura': abrevCtrl.text.trim().toUpperCase(),
      };
      if (esEdicion) {
        data['id'] = categoria['id'];
        await db.actualizar('categorias_producto', data);
      } else {
        data['orden'] = _categorias.length + 1;
        data['activo'] = 1; // Asegurar que nazca activa
        await db.insertar('categorias_producto', data);
      }
      _cargar();
    }
  }

  Future<void> _cambiarEstado(int id, String nombre, bool activar) async {
    final accion = activar ? 'reactivar' : 'desactivar';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('¿${accion.toUpperCase()}?',
            style: TextStyle(color: activar ? Colors.green : Colors.red, fontFamily: 'CourierNew')),
        content: Text('Se va a $accion "$nombre"',
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NO', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('SÍ', style: TextStyle(color: activar ? Colors.green : Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.actualizar('categorias_producto', {
        'id': id,
        'activo': activar ? 1 : 0,
      });
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('CATEGORÍAS DE PRODUCTO')),
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
                    child: Text(
                      c['abreviatura'] ?? '?',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  title: Text('${c['nombre'] ?? ''} ${activo ? "" : "(INACTIVO)"}',
                      style: TextStyle(color: activo ? Colors.white : Colors.white38, fontFamily: 'CourierNew')),
                  subtitle: Text('Orden: ${c['orden'] ?? '-'}',
                      style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: Icon(Icons.edit, color: Colors.yellow),
                          onPressed: () => _editar(categoria: c)),
                      IconButton(
                          icon: Icon(activo ? Icons.delete : Icons.restore, 
                              color: activo ? Colors.red : Colors.green),
                          onPressed: () => _cambiarEstado(c['id'] as int, c['nombre'] ?? '', !activo)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}