import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class ProductosScreen extends StatefulWidget {
  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _puntosVenta = [];
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
    final productos = await db.getProductos();
    final categorias = await db.getCategoriasProducto();
    final puntos = await db.getPuntosVenta();
    setState(() {
      _productos = productos;
      _categorias = categorias;
      _puntosVenta = puntos.where((p) => p['id'] != 1).toList();
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _productos;
    final q = _busqueda.toLowerCase();
    return _productos.where((p) {
      final cod = (p['codigo'] ?? '').toString().toLowerCase();
      final nom = (p['nombre'] ?? '').toString().toLowerCase();
      final cat = (p['categoria_nombre'] ?? '').toString().toLowerCase();
      return cod.contains(q) || nom.contains(q) || cat.contains(q);
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
      await db.eliminarProductoLogico(id);
      _cargarTodo();
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? producto}) async {
    final codigoCtrl = TextEditingController(text: producto?['codigo'] ?? '');
    final nombreCtrl = TextEditingController(text: producto?['nombre'] ?? '');
    int? categoriaId = producto?['categoria_id'] as int?;
    if (categoriaId == null && _categorias.isNotEmpty) {
      categoriaId = _categorias.first['id'] as int;
    }

    final Map<int, TextEditingController> preciosCtrl = {};
    if (producto != null) {
      final precios = await Provider.of<DatabaseHelper>(context, listen: false)
          .getPreciosDeProducto(producto['id'] as int);
      for (var pv in _puntosVenta) {
        final match = precios.firstWhere(
          (p) => p['punto_venta_id'] == pv['id'],
          orElse: () => {'precio': 0.0},
        );
        preciosCtrl[pv['id'] as int] = TextEditingController(
          text: (match['precio'] ?? 0.0).toString(),
        );
      }
    } else {
      for (var pv in _puntosVenta) {
        preciosCtrl[pv['id'] as int] = TextEditingController(text: '0.0');
      }
    }

    if (!mounted) return;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          producto == null ? 'NUEVO PRODUCTO' : 'EDITAR PRODUCTO',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoCtrl,
                decoration: InputDecoration(labelText: 'Código (ej: A01)'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: nombreCtrl,
                decoration: InputDecoration(labelText: 'Nombre'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: categoriaId,
                dropdownColor: Colors.black,
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                decoration: InputDecoration(labelText: 'Categoría'),
                items: _categorias.map<DropdownMenuItem<int>>((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(
                      '${c['abreviatura'] ?? ''} - ${c['nombre']}',
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (v) => categoriaId = v,
              ),
              SizedBox(height: 15),
              Text('PRECIOS POR PUNTO DE VENTA',
                  style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 11)),
              SizedBox(height: 10),
              ..._puntosVenta.map((pv) {
                final id = pv['id'] as int;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: preciosCtrl[id],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${pv['codigo']} - ${pv['nombre']}',
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13),
                  ),
                );
              }).toList(),
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
      if (codigoCtrl.text.trim().isEmpty || nombreCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete código y nombre'), backgroundColor: Colors.red),
        );
        return;
      }
      final Map<int, double> precios = {};
      for (var entry in preciosCtrl.entries) {
        precios[entry.key] = double.tryParse(entry.value.text) ?? 0.0;
      }
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      try {
        if (producto == null) {
          await db.insertarProductoConPrecios(
            codigo: codigoCtrl.text.trim(),
            nombre: nombreCtrl.text.trim(),
            categoriaId: categoriaId!,
            precios: precios,
          );
        } else {
          await db.actualizarProductoConPrecios(
            productoId: producto['id'] as int,
            codigo: codigoCtrl.text.trim(),
            nombre: nombreCtrl.text.trim(),
            categoriaId: categoriaId!,
            precios: precios,
          );
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
        title: Text('PRODUCTOS (${filtrados.length})'),
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
                hintText: 'Buscar por código, nombre o categoría...',
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
                        child: Text('Sin productos',
                            style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew')),
                      )
                    : ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) {
                          final p = filtrados[i];
                          final activo = (p['activo'] ?? 1) == 1;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: activo ? Colors.yellow : Colors.grey,
                              child: Text(
                                p['codigo'] ?? '?',
                                style: TextStyle(
                                    color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              p['nombre'] ?? '',
                              style: TextStyle(
                                color: activo ? Colors.white : Colors.white38,
                                fontFamily: 'CourierNew',
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${p['categoria_abrev'] ?? ''} - ${p['categoria_nombre'] ?? ''}',
                              style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.yellow, size: 20),
                                  onPressed: () => _abrirFormulario(producto: p),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _eliminar(p['id'] as int, p['nombre'] ?? ''),
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