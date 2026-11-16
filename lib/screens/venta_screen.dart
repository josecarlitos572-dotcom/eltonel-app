import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class VentaScreen extends StatefulWidget {
  @override
  _VentaScreenState createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<Map<String, dynamic>> _carrito = [];
  double _total = 0.0;
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;
  int _puntoVentaId = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final pv = auth.currentUser?['punto_venta_id_actual'] as int? ?? 2;
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final prods = await db.getProductos();
    
    if (mounted) {
      setState(() {
        _puntoVentaId = pv;
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

  Future<void> _finalizarVenta(String tipoVenta) async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final usuarioId = auth.currentUser?['id'] as int? ?? 1;
    
    String nombreCliente = 'Cliente Varios';
    String telefonoCliente = '';
    int? clienteId;

    if (tipoVenta == 'CREDITO') {
      final nombreCtrl = TextEditingController();
      final fonoCtrl = TextEditingController();
      
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.black,
          title: Text('DATOS DEL CLIENTE (FIADO)', style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                decoration: InputDecoration(labelText: 'Nombre del cliente', labelStyle: TextStyle(color: Colors.yellow)),
              ),
              TextField(
                controller: fonoCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                decoration: InputDecoration(labelText: 'Celular', labelStyle: TextStyle(color: Colors.yellow)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCELAR', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ACEPTAR', style: TextStyle(color: Colors.yellow))),
          ],
        ),
      );
      
      if (ok != true) return;
      if (nombreCtrl.text.trim().isEmpty || fonoCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nombre y celular son obligatorios'), backgroundColor: Colors.red));
        return;
      }
      
      nombreCliente = nombreCtrl.text.trim();
      telefonoCliente = fonoCtrl.text.trim();
      clienteId = await db.registrarClienteSiNoExiste(nombreCliente, telefonoCliente);
    }

    final ventaData = {
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'punto_venta_id': _puntoVentaId,
      'fecha': DateTime.now().toIso8601String(),
      'tipo_venta': tipoVenta,
      'monto_total': _total,
      'vuelto': 0.0,
      'tiene_comprobante': 0,
      'nombre_cliente': nombreCliente,
      'telefono_cliente': telefonoCliente,
    };

    final items = _carrito.map((item) => {
      'id': item['id'],
      'qty': item['cantidad'],
      'price': item['precio'],
    }).toList();

    try {
      await db.registrarVenta(ventaData, items, esCredito: tipoVenta == 'CREDITO');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta ($tipoVenta) registrada. Total: S/ ${_total.toStringAsFixed(2)}')),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 16 - 8) / 2; 
                final height = width / 1.5;
                
                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
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
                    child: Column(
                      children: [
                        Text(
                          'TOTAL: S/ ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50),
                                ),
                                onPressed: _carrito.isEmpty ? null : () => _finalizarVenta('EFECTIVO'),
                                child: const Text('EFECTIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50),
                                ),
                                onPressed: _carrito.isEmpty ? null : () => _finalizarVenta('ELECTRONICO'),
                                child: const Text('YAPE/PLIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50),
                                ),
                                onPressed: _carrito.isEmpty ? null : () => _finalizarVenta('CREDITO'),
                                child: const Text('FIADO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
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