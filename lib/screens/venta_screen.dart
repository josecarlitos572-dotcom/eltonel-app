import 'package:flutter/material.dart';

class VentaScreen extends StatefulWidget {
  @override
  _VentaScreenState createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<Map<String, dynamic>> _carrito = [];
  double _total = 0.0;

  // AQUÍ DEBES CONECTAR TU BASE DE DATOS SQLITE PARA TRAER LOS PRODUCTOS REALES
  final List<Map<String, dynamic>> _productos = [
    {'id': 1, 'nombre': 'Desayuno Clásico', 'precio': 10.0},
    {'id': 2, 'nombre': 'Desayuno Especial', 'precio': 15.0},
    {'id': 3, 'nombre': 'Café Solo', 'precio': 3.0},
    {'id': 4, 'nombre': 'Jugo Natural', 'precio': 5.0},
  ];

  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      final index = _carrito.indexWhere((item) => item['id'] == producto['id']);
      if (index >= 0) {
        _carrito[index]['cantidad']++;
      } else {
        _carrito.add({...producto, 'cantidad': 1});
      }
      _total += producto['precio'];
    });
  }

  void _quitarDelCarrito(int index) {
    setState(() {
      _total -= (_carrito[index]['precio'] * _carrito[index]['cantidad']);
      _carrito.removeAt(index);
    });
  }

  Future<void> _finalizarVenta() async {
    // AQUÍ DEBES INSERTAR LA VENTA EN TU BASE DE DATOS SQLITE
    // Ejemplo: await DatabaseHelper.instance.insertVenta(...);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('¡Venta registrada! Total: S/ ${_total.toStringAsFixed(2)}')),
    );
    
    setState(() {
      _carrito.clear();
      _total = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vender - El Tonel'),
        backgroundColor: Colors.orange,
        automaticallyImplyLeading: false, // Quita el botón de atrás para que no se salgan
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final prod = _productos[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[50],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _agregarAlCarrito(prod),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(prod['nombre'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text('S/ ${prod['precio'].toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.green)),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: const Border(top: BorderSide(color: Colors.grey, width: 2)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _carrito.isEmpty
                        ? const Center(child: Text('No hay productos', style: TextStyle(fontSize: 18, color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _carrito.length,
                            itemBuilder: (context, index) {
                              final item = _carrito[index];
                              return ListTile(
                                title: Text('${item['cantidad']}x ${item['nombre']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _quitarDelCarrito(index),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'TOTAL: S/ ${_total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(150, 60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _carrito.isEmpty ? null : _finalizarVenta,
                          child: const Text('COBRAR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}