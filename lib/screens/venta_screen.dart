import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class VentaScreen extends StatefulWidget {
  final int? puntoVentaId;
  const VentaScreen({Key? key, this.puntoVentaId}) : super(key: key);

  @override
  _VentaScreenState createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  List<Map<String, dynamic>> carrito = [];
  double total = 0.0;
  String tipoPago = 'contado';
  final TextEditingController _nombreClienteCtrl = TextEditingController();
  int categoriaSeleccionada = 1;

  static const double IGV = 0.18;
  static const int CANT_DEFECTO = 6;

  List<Map<String, dynamic>> _categorias = [];
  Map<int, double> _preciosPorProducto = {};
  bool _cargando = true;

  int get _pvId {
    if (widget.puntoVentaId != null) return widget.puntoVentaId!;
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.currentUser?['punto_venta_id'] ?? 2;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final cats = await db.getCategoriasProducto();
    final productos = db.products;

    final Map<int, double> precios = {};
    for (var p in productos) {
      final listaPrecios = await db.getPreciosDeProducto(p['id'] as int);
      final pvPrecio = listaPrecios.firstWhere(
        (pr) => pr['punto_venta_id'] == _pvId,
        orElse: () => {'precio': 2.0},
      );
      precios[p['id'] as int] = (pvPrecio['precio'] as num).toDouble();
    }

    if (mounted) {
      setState(() {
        _categorias = cats;
        _preciosPorProducto = precios;
        _cargando = false;
      });
    }
  }

  double _precioProducto(int productoId) {
    return _preciosPorProducto[productoId] ?? 2.0;
  }

  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      final precio = _precioProducto(producto['id'] as int);
      final existing = carrito.firstWhere(
        (p) => p['id'] == producto['id'],
        orElse: () => {},
      );
      if (existing.isNotEmpty) {
        existing['qty'] += 1;
      } else {
        carrito.add({
          ...producto,
          'qty': CANT_DEFECTO,
          'price': precio,
        });
      }
      _calcularTotal();
    });
  }

  void _quitarDelCarrito(int index) {
    setState(() {
      carrito.removeAt(index);
      _calcularTotal();
    });
  }

  void _cambiarCantidad(int index, int delta) {
    setState(() {
      final nuevo = (carrito[index]['qty'] as int) + delta;
      if (nuevo < 1) return;
      carrito[index]['qty'] = nuevo;
      _calcularTotal();
    });
  }

  void _calcularTotal() {
    total = carrito.fold(
      0,
      (sum, item) => sum + ((item['price'] as num) * (item['qty'] as num)),
    );
  }

  double get _subtotalCalc => total / (1 + IGV);
  double get _igvCalc => total - _subtotalCalc;

  void _enviarWSP() async {
    String texto = "DESAYUNOS EL TONEL\nPedido:\n";
    for (var item in carrito) {
      texto += "- ${item['qty']}x ${item['nombre']} (S/.${item['price']})\n";
    }
    texto += "\nSubtotal: S/. ${_subtotalCalc.toStringAsFixed(2)}";
    texto += "\nIGV (18%): S/. ${_igvCalc.toStringAsFixed(2)}";
    texto += "\nTOTAL: S/. ${total.toStringAsFixed(2)}";
    texto += "\nPagado con: ${tipoPago.toUpperCase()}";
    final Uri url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(texto)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _finalizarVenta() async {
    if (carrito.isEmpty) return;

    if (tipoPago == 'credito') {
      if (_nombreClienteCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nombre obligatorio para crédito'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    Map<String, dynamic> ventaData = {
      'cliente_id': 1,
      'usuario_id': auth.currentUser?['id'] ?? 1,
      'punto_venta_id': _pvId,
      'fecha': DateTime.now().toIso8601String(),
      'tipo_venta': tipoPago,
      'monto_total': total,
      'vuelto': 0.0,
      'tiene_comprobante': 0,
      if (tipoPago == 'credito') ...{
        'nombre_cliente': _nombreClienteCtrl.text,
        'fecha_vencimiento': DateTime.now()
            .add(Duration(days: 1))
            .toIso8601String()
            .split('T')[0],
      }
    };

    try {
      await dbHelper.registrarVenta(ventaData, carrito);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.black,
          title: Text('VENTA EXITOSA',
              style: TextStyle(color: Colors.green, fontFamily: 'CourierNew')),
          content: Text(
            'Total: S/ ${total.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _enviarWSP();
                Navigator.pop(ctx);
              },
              child: Text('ENVIAR WSP', style: TextStyle(color: Colors.yellow)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CERRAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      setState(() {
        carrito.clear();
        total = 0.0;
        _nombreClienteCtrl.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('NUEVA VENTA'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    final dbHelper = Provider.of<DatabaseHelper>(context);
    final productosFiltrados = dbHelper.products
        .where((p) => p['categoria_id'] == categoriaSeleccionada)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('NUEVA VENTA'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            height: 55,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 5),
              itemCount: _categorias.length,
              itemBuilder: (ctx, i) {
                final cat = _categorias[i];
                final abrev = cat['abreviatura'] ?? 'CAT';
                final activa = (cat['id'] as int) == categoriaSeleccionada;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ElevatedButton(
                    onPressed: () =>
                        setState(() => categoriaSeleccionada = cat['id'] as int),
                    child: Text(abrev,
                        style: TextStyle(
                            fontFamily: 'CourierNew', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activa ? Colors.orange : Colors.yellow,
                      foregroundColor: Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: productosFiltrados.length,
              itemBuilder: (ctx, i) {
                final prod = productosFiltrados[i];
                final precio = _precioProducto(prod['id'] as int);
                return ListTile(
                  dense: true,
                  title: Text(
                    prod['nombre'],
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'CourierNew',
                        fontSize: 13),
                  ),
                  subtitle: Text(
                    '${prod['codigo']} - S/ ${precio.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'CourierNew',
                        fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.yellow),
                    onPressed: () => _agregarAlCarrito(prod),
                  ),
                );
              },
            ),
          ),

          Container(
            constraints: BoxConstraints(maxHeight: 150),
            color: Color(0xFF1A1A1A),
            child: carrito.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(15),
                    child: Text('Carrito vacío',
                        style: TextStyle(
                            color: Colors.white38,
                            fontFamily: 'CourierNew',
                            fontSize: 12)),
                  )
                : ListView.builder(
                    itemCount: carrito.length,
                    itemBuilder: (ctx, i) {
                      final item = carrito[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${item['nombre']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 12),
                        ),
                        subtitle: Text(
                          '${item['qty']}x S/ ${(item['price'] as num).toStringAsFixed(2)} = S/ ${((item['price'] as num) * (item['qty'] as num)).toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Colors.yellow,
                              fontFamily: 'CourierNew',
                              fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove,
                                  color: Colors.orange, size: 18),
                              onPressed: () => _cambiarCantidad(i, -1),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            IconButton(
                              icon: Icon(Icons.add,
                                  color: Colors.green, size: 18),
                              onPressed: () => _cambiarCantidad(i, 1),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.red, size: 18),
                              onPressed: () => _quitarDelCarrito(i),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          Container(
            color: Colors.grey[900],
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'CourierNew',
                            fontSize: 11)),
                    Text('S/ ${_subtotalCalc.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'CourierNew',
                            fontSize: 11)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('IGV (18%):',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'CourierNew',
                            fontSize: 11)),
                    Text('S/ ${_igvCalc.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'CourierNew',
                            fontSize: 11)),
                  ],
                ),
                Divider(color: Colors.yellow, height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL:',
                        style: TextStyle(
                            color: Colors.yellow,
                            fontFamily: 'CourierNew',
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text('S/ ${total.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.yellow,
                            fontFamily: 'CourierNew',
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),

                if (tipoPago == 'credito')
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _nombreClienteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre Cliente',
                        labelStyle: TextStyle(color: Colors.yellow),
                        isDense: true,
                      ),
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                  ),

                SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: Text('CONTADO',
                          style: TextStyle(
                              fontFamily: 'CourierNew', fontSize: 12)),
                      selected: tipoPago == 'contado',
                      onSelected: (val) =>
                          setState(() => tipoPago = 'contado'),
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.black),
                    ),
                    ChoiceChip(
                      label: Text('CRÉDITO',
                          style: TextStyle(
                              fontFamily: 'CourierNew', fontSize: 12)),
                      selected: tipoPago == 'credito',
                      onSelected: (val) =>
                          setState(() => tipoPago = 'credito'),
                      selectedColor: Colors.orange,
                      labelStyle: TextStyle(color: Colors.black),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                ElevatedButton(
                  onPressed: _finalizarVenta,
                  child: Text('CONFIRMAR VENTA'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}