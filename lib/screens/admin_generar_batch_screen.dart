import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class AdminGenerarBatchScreen extends StatefulWidget {
  @override
  _AdminGenerarBatchScreenState createState() => _AdminGenerarBatchScreenState();
}

class _AdminGenerarBatchScreenState extends State<AdminGenerarBatchScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _puntos = [];
  List<Map<String, dynamic>> _carrito = [];
  bool _cargando = true;
  String _busqueda = '';
  String _tipo = 'ABASTO';
  int? _pvDestinoId;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final productos = await db.getProductos();
    final puntos = await db.getPuntosVenta();

    if (mounted) {
      setState(() {
        _productos = productos.where((p) => (p['activo'] ?? 1) == 1).toList();
        _puntos = puntos.where((p) => p['id'] != 1).toList();
        if (_puntos.isNotEmpty) {
          _pvDestinoId = _puntos.first['id'] as int;
        }
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _productos;
    final q = _busqueda.toLowerCase();
    return _productos.where((p) {
      final cod = (p['codigo'] ?? '').toString().toLowerCase();
      final nom = (p['nombre'] ?? '').toString().toLowerCase();
      return cod.contains(q) || nom.contains(q);
    }).toList();
  }

  void _agregar(Map<String, dynamic> producto) {
    setState(() {
      final existing = _carrito.firstWhere(
        (p) => p['producto_id'] == producto['id'],
        orElse: () => {},
      );
      if (existing.isNotEmpty) {
        existing['cantidad'] += 1;
      } else {
        _carrito.add({
          'producto_id': producto['id'],
          'codigo': producto['codigo'],
          'nombre': producto['nombre'],
          'cantidad': 6,
        });
      }
    });
  }

  void _quitar(int i) {
    setState(() => _carrito.removeAt(i));
  }

  void _cambiarCantidad(int i, int delta) {
    setState(() {
      final nuevo = (_carrito[i]['cantidad'] as int) + delta;
      if (nuevo < 1) return;
      _carrito[i]['cantidad'] = nuevo;
    });
  }

  int get _totalUnidades {
    return _carrito.fold(0, (s, e) => s + (e['cantidad'] as int));
  }

  Future<void> _generarBatch() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agrega productos al carrito'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_pvDestinoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecciona un punto de venta'), backgroundColor: Colors.orange),
      );
      return;
    }

    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final db2 = await db.database;

    final pvDestino = _puntos.firstWhere((p) => p['id'] == _pvDestinoId);
    final pvCodigo = pvDestino['codigo'] as String;

    final movs = await db2.rawQuery(
      'SELECT COUNT(*) as total FROM batches_generados WHERE origen = ? AND tipo = ?',
      ['BASE', _tipo],
    );
    final sec = ((movs.first['total'] as int?) ?? 0) + 1;

    final previos = await db2.query('batches_generados',
        where: 'origen = ?', whereArgs: ['BASE'], orderBy: 'id DESC', limit: 1);
    final hashAnterior = previos.isNotEmpty
        ? (previos.first['hash'] as String? ?? 'sha256:0000')
        : 'sha256:0000';

    final payload = {
      'items': _carrito
          .map((e) => {
                'producto_id': e['producto_id'],
                'cantidad': e['cantidad'],
              })
          .toList(),
    };

    final contenidoPayload = jsonEncode(payload);
    final hash = 'sha256:${sha256.convert(utf8.encode(contenidoPayload))}';

    final batch = {
      'header': {
        'tipo': _tipo,
        'version': 1,
        'origen': 'BASE',
        'destino': pvCodigo,
        'fecha_generacion': DateTime.now().toIso8601String(),
        'periodo': _hoy,
        'secuencial': sec,
        'hash_anterior': hashAnterior,
        'hash': hash,
      },
      'payload': payload,
    };

    final jsonStr = jsonEncode(batch);

    await db2.insert('batches_generados', {
      'tipo': _tipo,
      'origen': 'BASE',
      'destino': pvCodigo,
      'periodo': _hoy,
      'secuencial': sec,
      'hash': hash,
      'hash_anterior': hashAnterior,
      'contenido_json': jsonStr,
      'fecha_generacion': DateTime.now().toIso8601String(),
      'estado': 'GENERADO',
    });

    await db2.insert('auditoria_cambios', {
      'fecha': DateTime.now().toIso8601String(),
      'usuario_id': auth.currentUser?['id'],
      'usuario_nombre': auth.currentUser?['nombres'] ?? '',
      'tabla_afectada': 'batches_generados',
      'accion': 'BATCH_GENERADO',
      'registro_id': sec,
      'datos_anteriores': null,
      'datos_nuevos': 'Tipo: $_tipo | Destino: $pvCodigo | Items: ${_carrito.length}',
    });

    if (!mounted) return;
    _mostrarBatch(jsonStr, _tipo, pvCodigo);
  }

  void _mostrarBatch(String json, String tipo, String destino) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('BATCH $tipo → $destino',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 13)),
        content: Container(
          width: double.maxFinite,
          height: 400,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            border: Border.all(color: Colors.yellow),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 9),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final Uri url = Uri.parse(
                  'whatsapp://send?text=${Uri.encodeComponent(json)}');
              launchUrl(url);
            },
            child: Text('ENVIAR WSP', style: TextStyle(color: Colors.yellow)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _carrito.clear();
              });
            },
            child: Text('CERRAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('GENERAR BATCH'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: Text('GENERAR BATCH'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            color: Color(0xFF1A1A1A),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('TIPO: ',
                        style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 12)),
                    SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tipo,
                        dropdownColor: Colors.black,
                        style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Tipo',
                          labelStyle: TextStyle(color: Colors.yellow),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: 'ABASTO', child: Text('ABASTO', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'REABASTO', child: Text('REABASTO', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (v) => setState(() => _tipo = v ?? 'ABASTO'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _pvDestinoId,
                  dropdownColor: Colors.black,
                  style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Punto de venta destino',
                    labelStyle: TextStyle(color: Colors.yellow),
                    isDense: true,
                  ),
                  items: _puntos.map<DropdownMenuItem<int>>((p) {
                    return DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text('${p['codigo']} - ${p['nombre']}',
                          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _pvDestinoId = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: Colors.yellow),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: filtrados.length,
              itemBuilder: (ctx, i) {
                final p = filtrados[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.yellow,
                    child: Text(p['codigo'] ?? '?',
                        style: TextStyle(
                            color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p['nombre'] ?? '',
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.yellow, size: 22),
                    onPressed: () => _agregar(p),
                  ),
                );
              },
            ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: 180),
            color: Color(0xFF1A1A1A),
            child: _carrito.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Carrito vacío',
                        style: TextStyle(
                            color: Colors.white38, fontFamily: 'CourierNew', fontSize: 11)),
                  )
                : ListView.builder(
                    itemCount: _carrito.length,
                    itemBuilder: (ctx, i) {
                      final item = _carrito[i];
                      return ListTile(
                        dense: true,
                        title: Text('${item['codigo']} ${item['nombre']}',
                            style: TextStyle(
                                color: Colors.white, fontFamily: 'CourierNew', fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: Colors.orange, size: 18),
                              onPressed: () => _cambiarCantidad(i, -1),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            Container(
                              width: 30,
                              alignment: Alignment.center,
                              child: Text('${item['cantidad']}',
                                  style: TextStyle(
                                      color: Colors.yellow,
                                      fontFamily: 'CourierNew',
                                      fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: Colors.green, size: 18),
                              onPressed: () => _cambiarCantidad(i, 1),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red, size: 18),
                              onPressed: () => _quitar(i),
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
            padding: EdgeInsets.all(10),
            color: Colors.grey[900],
            child: Column(
              children: [
                Text(
                  '${_carrito.length} productos · $_totalUnidades unidades',
                  style: TextStyle(
                      color: Colors.white70, fontFamily: 'CourierNew', fontSize: 11),
                ),
                SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: _generarBatch,
                  icon: Icon(Icons.send, color: Colors.black),
                  label: Text('GENERAR Y ENVIAR BATCH'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    textStyle: TextStyle(
                        fontFamily: 'CourierNew',
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
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