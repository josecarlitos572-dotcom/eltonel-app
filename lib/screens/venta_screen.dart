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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin precio para este PV'), backgroundColor: Colors.red),
      );
      return;
    }

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
    
    String nombreCliente = 'Consumidor Final';
    String telefonoCliente = '';
    String dniCliente = '';
    int? clienteId;
    bool requiereComprobante = false;

    if (tipoVenta == 'CREDITO' || tipoVenta == 'ELECTRONICO') {
      final dniCtrl = TextEditingController();
      final nombreCtrl = TextEditingController();
      final fonoCtrl = TextEditingController();
      
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(tipoVenta == 'CREDITO' ? 'REGISTRAR FIADO' : 'DATOS COMANDA', 
              style: const TextStyle(color: Color(0xFFFFC107), fontFamily: 'CourierNew', fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del cliente'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dniCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'DNI (Opcional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Celular (Opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ACEPTAR', style: TextStyle(color: Color(0xFFFFC107)))),
          ],
        ),
      );
      
      if (ok != true) return;

      nombreCliente = nombreCtrl.text.trim().isEmpty ? 'Cliente Varios' : nombreCtrl.text.trim();
      telefonoCliente = fonoCtrl.text.trim();
      dniCliente = dniCtrl.text.trim();
      requiereComprobante = tipoVenta == 'ELECTRONICO';

      if (tipoVenta == 'CREDITO' && nombreCliente == 'Cliente Varios') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Para fiar, el nombre es obligatorio'), backgroundColor: Colors.red));
        return;
      }

      if (dniCliente.isNotEmpty) {
        clienteId = await db.registrarClienteSiNoExiste(nombreCliente, telefonoCliente, dniCliente);
      }
    }

    final ventaData = {
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'punto_venta_id': _puntoVentaId,
      'fecha': DateTime.now().toIso8601String(),
      'tipo_venta': tipoVenta,
      'monto_total': _total,
      'vuelto': 0.0,
      'tiene_comprobante': requiereComprobante ? 1 : 0,
      'nombre_cliente': nombreCliente,
      'telefono_cliente': telefonoCliente,
      'dni_cliente': dniCliente,
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
        SnackBar(content: Text('Venta ($tipoVenta) OK. Total: S/ ${_total.toStringAsFixed(2)}'), backgroundColor: Colors.green),
      );
      
      setState(() {
        _carrito.clear();
        _total = 0.0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NUEVA VENTA'),
        automaticallyImplyLeading: false,
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Text('S/ ${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, color: Color(0xFFFFC107), fontWeight: FontWeight.bold)),
          ))
        ],
      ),
      body: Column(
        children: [
          // GRILLA DE PRODUCTOS MEJORADA
          Expanded(
            flex: 3,
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              physics: const PageScrollPhysics(), 
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _productos.length,
              itemBuilder: (context, index) {
                final prod = _productos[index];
                return Material(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _agregarAlCarrito(prod),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(4)),
                            child: Text(prod['codigo'], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                          Text(prod['nombre'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Toca para agregar', style: TextStyle(color: Colors.white38, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // CARRITO Y TOTAL
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: _carrito.isEmpty
                        ? const Center(child: Text('Carrito Vacío', style: TextStyle(color: Colors.white38, fontSize: 16)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            itemCount: _carrito.length,
                            itemBuilder: (context, index) {
                              final item = _carrito[index];
                              return Card(
                                color: const Color(0xFF2C2C2C),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  dense: true,
                                  title: Text('${item['cantidad']} x ${item['nombre']}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  subtitle: Text('Subtotal: S/ ${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 11)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () => _quitarDelCarrito(index),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // BOTONES DE COBRO GIGANTES
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 60),
                            ),
                            onPressed: _carrito.isEmpty ? null : () => _finalizarVenta('EFECTIVO'),
                            child: const Column(
                              children: [
                                Icon(Icons.money, size: 24),
                                Text('EFECTIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 60),
                            ),
                            onPressed: _carrito.isEmpty ? null : () => _finalizarVenta('ELECTRONICO'),
                            child: const Column(
                              children: [
                                Icon(Icons.account_balance_wallet, size: 24),
                                Text('YAPE/PLIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 60),
                            ),
                            onPressed: _carrito.isEmpty ? null : () => _finalizarVenta('CREDITO'),
                            child: const Column(
                              children: [
                                Icon(Icons.handshake, size: 24),
                                Text('FIADO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
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