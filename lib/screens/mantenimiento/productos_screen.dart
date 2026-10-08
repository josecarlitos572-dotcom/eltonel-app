import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class ProductosScreen extends StatefulWidget {
  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final data = await db.getProductos();
    setState(() {
      _productos = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PRODUCTOS (${_productos.length})'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _cargar)],
      ),
      backgroundColor: Colors.black,
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.yellow))
          : ListView.builder(
              itemCount: _productos.length,
              itemBuilder: (context, i) {
                final p = _productos[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.yellow,
                    child: Text(
                      p['codigo'] ?? '?',
                      style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    p['nombre'] ?? '',
                    style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                  ),
                  subtitle: Text(
                    '${p['categoria_nombre'] ?? ''} · ${p['categoria_abrev'] ?? ''}',
                    style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11),
                  ),
                );
              },
            ),
    );
  }
}