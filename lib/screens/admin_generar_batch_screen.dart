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
  Map<int, TextEditingController> _cantidades = {};
  bool _cargando = true;
  String _busqueda = '';
  String _tipo = 'ABASTO';
  int? _pvDestinoId;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo()); }
  @override
  void dispose() { for (var c in _cantidades.values) c.dispose(); super.dispose(); }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final productos = (await db.getProductos()).where((p) => (p['activo'] ?? 1) == 1).toList();
    final puntos = (await db.getPuntosVenta()).where((p) => p['id'] != 1).toList();
    _cantidades = {for (var p in productos) p['id'] as int: TextEditingController()};
    if (mounted) setState(() { _productos = productos; _puntos = puntos; _pvDestinoId = puntos.isNotEmpty ? puntos.first['id'] as int : null; _cargando = false; });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _productos;
    final q = _busqueda.toLowerCase();
    return _productos.where((p) => '${p['codigo']} ${p['nombre']}'.toLowerCase().contains(q)).toList();
  }

  int get _totalUnidades { int t = 0; _cantidades.forEach((_, c) => t += int.tryParse(c.text) ?? 0); return t; }
  int get _totalProductos => _cantidades.values.where((c) => (int.tryParse(c.text) ?? 0) > 0).length;

  Future<void> _generarBatch() async {
    if (_pvDestinoId == null) { _aviso('Selecciona un punto de venta', Colors.orange); return; }
    final db = context.read<DatabaseHelper>();
    final db2 = await db.database;
    final pvDestino = _puntos.firstWhere((p) => p['id'] == _pvDestinoId);
    final pvCodigo = pvDestino['codigo'] as String;

    final carrito = <Map<String, dynamic>>[];
    for (var p in _productos) { final c = int.tryParse(_cantidades[p['id']]?.text ?? '') ?? 0; if (c > 0) carrito.add({'producto_id': p['id'], 'cantidad': c}); }
    if (carrito.isEmpty) { _aviso('Asigna cantidad a al menos un producto', Colors.orange); return; }

    final sec = (((await db2.rawQuery('SELECT COUNT(*) as total FROM batches_generados WHERE origen = ? AND tipo = ?', ['BASE', _tipo])).first['total'] as int?) ?? 0) + 1;
    final previos = await db2.query('batches_generados', where: 'origen = ?', whereArgs: ['BASE'], orderBy: 'id DESC', limit: 1);
    final hashAnterior = previos.isNotEmpty ? (previos.first['hash'] as String? ?? 'sha256:0000') : 'sha256:0000';
    final payload = {'items': carrito};
    final hash = 'sha256:${sha256.convert(utf8.encode(jsonEncode(payload)))}';
    final batch = {'header': {'tipo': _tipo, 'version': 1, 'origen': 'BASE', 'destino': pvCodigo, 'fecha_generacion': DateTime.now().toIso8601String(), 'periodo': _hoy, 'secuencial': sec, 'hash_anterior': hashAnterior, 'hash': hash}, 'payload': payload};
    await db2.insert('batches_generados', {'tipo': _tipo, 'origen': 'BASE', 'destino': pvCodigo, 'periodo': _hoy, 'secuencial': sec, 'hash': hash, 'hash_anterior': hashAnterior, 'contenido_json': jsonEncode(batch), 'fecha_generacion': DateTime.now().toIso8601String(), 'estado': 'GENERADO'});

    final auth = context.read<AuthService>();
    await db2.insert('auditoria_cambios', {'fecha': DateTime.now().toIso8601String(), 'usuario_id': auth.currentUser?['id'], 'usuario_nombre': auth.currentUser?['nombres'] ?? '', 'tabla_afectada': 'batches_generados', 'accion': 'BATCH_GENERADO', 'registro_id': sec, 'datos_anteriores': null, 'datos_nuevos': 'Tipo: $_tipo | Destino: $pvCodigo | Items: ${carrito.length}'});
    if (!mounted) return;
    _mostrarBatch(jsonEncode(batch), _tipo, pvCodigo);
  }

  void _aviso(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  void _mostrarBatch(String json, String tipo, String destino) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black,
      title: Text('BATCH $tipo → $destino', style: const TextStyle(color: Colors.yellow, fontSize: 13)),
      content: SizedBox(width: double.maxFinite, height: 400, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.yellow)), child: SingleChildScrollView(child: SelectableText(json, style: const TextStyle(color: Colors.white, fontSize: 9))))),
      actions: [
        TextButton(onPressed: () => launchUrl(Uri.parse('whatsapp://send?text=${Uri.encodeComponent(json)}')), child: const Text('ENVIAR WSP', style: TextStyle(color: Colors.yellow))),
        TextButton(onPressed: () { Navigator.pop(ctx); setState(() { for (var c in _cantidades.values) c.clear(); }); }, child: const Text('CERRAR', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(
      appBar: AppBar(title: const Text('CARGA MASIVA (STOCK)'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: Column(children: [
        Container(padding: const EdgeInsets.all(10), color: const Color(0xFF1A1A1A), child: Column(children: [
          Row(children: [
            const Text('TIPO: ', style: TextStyle(color: Colors.yellow, fontSize: 12)),
            Expanded(child: DropdownButtonFormField<String>(value: _tipo, dropdownColor: Colors.black, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(labelText: 'Tipo', labelStyle: TextStyle(color: Colors.yellow), isDense: true),
              items: const [DropdownMenuItem(value: 'ABASTO', child: Text('ABASTO')), DropdownMenuItem(value: 'REABASTO', child: Text('REABASTO'))],
              onChanged: (v) => setState(() => _tipo = v ?? 'ABASTO'))),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(value: _pvDestinoId, dropdownColor: Colors.black, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(labelText: 'Punto destino', labelStyle: TextStyle(color: Colors.yellow), isDense: true),
            items: _puntos.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['codigo']} - ${p['nombre']}'))).toList(),
            onChanged: (v) => setState(() => _pvDestinoId = v)),
        ])),
        Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => _busqueda = v), decoration: const InputDecoration(hintText: 'Buscar producto…', prefixIcon: Icon(Icons.search, color: Colors.yellow), filled: true, fillColor: Color(0xFF1A1A1A), isDense: true), style: const TextStyle(color: Colors.white, fontSize: 12))),
        Expanded(child: ListView.builder(itemCount: _filtrados.length, itemBuilder: (_, i) {
          final p = _filtrados[i];
          final id = p['id'] as int;
          return ListTile(dense: true,
            leading: CircleAvatar(backgroundColor: Colors.yellow, child: Text(p['codigo'] ?? '?', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
            title: Text(p['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
            trailing: SizedBox(width: 80, child: TextField(controller: _cantidades[id], keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: '0', isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: Colors.yellow))))));
        })),
        Container(padding: const EdgeInsets.all(10), color: Colors.grey[900], child: Column(children: [
          Text('$_totalProductos productos · $_totalUnidades unidades', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          ElevatedButton.icon(onPressed: _generarBatch, icon: const Icon(Icons.send, color: Colors.black), label: const Text('GENERAR BATCH'), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.yellow, foregroundColor: Colors.black, textStyle: const TextStyle(fontWeight: FontWeight.bold))),
        ])),
      ]),
    );
  }
}