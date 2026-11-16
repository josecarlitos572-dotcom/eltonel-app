import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class VentaScreen extends StatefulWidget {
  @override
  _VentaScreenState createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<Map<String, dynamic>> _carrito = [];
  double _total = 0.0;
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;

  // ID del punto de venta actual
  final int _puntoVentaId = 2; 

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final prods = await db.getProductos();
    if (mounted) {
      setState(() {
        _productos = prods;
        _cargando = false;
      });
    }
  }

  void _agregarAlCarrito(Map<String, dynamic> producto) async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final precios = await db.getPreciosDeProducto(producto['id']);
    double precio = 0.0;
    
    for (var p in precios) {
      if (p['punto_venta_id'] == _puntoVentaId) {
        precio = (p['precio'] as num).toDouble();
        break;
      }
    }

    if (precio == 0.0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto no tiene precio para este punto de venta')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        final index = _carrito.indexWhere((item) => item['id'] == producto['id']);
        if (index >= 0) {
          _carrito[index]['cantidad']++;
        } else {
          _carrito.add({
            'id': producto['id'],
            'nombre': producto['nombre'],
            'precio': precio,
            'cantidad': 1,
          });
        }
        _total += precio;
      });
    }
  }

  void _quitarDelCarrito(int index) {
    setState(() {
      _total -= (_carrito[index]['precio'] * _carrito[index]['cantidad']);
      _carrito.removeAt(index);
    });
  }

  Future<void> _finalizarVenta() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    
    final ventaData = {
      'cliente_id': null,
      'usuario_id': 1,
      'punto_venta_id': _puntoVentaId,
      'fecha': DateTime.now().toIso8601String(),
      'tipo_venta': 'EFECTIVO',
      'monto_total': _total,
      'vuelto': 0.0,
      'tiene_comprobante': 0,
      'nombre_cliente': 'Cliente Varios',
    };

    final items = _carrito.map((item) => {
      'id': item['id'],
      'qty': item['cantidad'],
      'price': item['precio'],
    }).toList();

    try {
      await db.registrarVenta(ventaData, items);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Venta registrada! Total: S/ ${_total.toStringAsFixed(2)}')),
      );
      
      setState(() {
        _carrito.clear();
        _total = 0.0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar venta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vender - El Tonel'),
        backgroundColor: Colors.orange,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: LayoutBuilder( // Usamos LayoutBuilder para calcular la altura exacta de la fila
              builder: (context, constraints) {
                // Calculamos el tamaño de la celda basado en el aspect ratio 1.5
                final width = (constraints.maxWidth - 16 - 8) / 2; 
                final height = width / 1.5;
                final itemExtent = height + 8; // Altura de la celda + margen

                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  // Aquí se ajusta el pitch para que salte de 1 fila (2 productos) a la vez
                  physics: const PageScrollPhysics(), 
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                          Text(prod['nombre'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(prod['codigo'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
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
                                subtitle: Text('S/ ${(item['precio'] * item['cantidad']).toStringAsFixed(2)}'),
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