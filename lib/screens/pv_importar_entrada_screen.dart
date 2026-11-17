// ============================================================
// pv_importar_entrada_screen.dart — Recepción de batch en PV
// Corrige pv a 'punto_venta_id_actual' y aplica batch MAESTRO
// (upsert de maestros + stock) además del de ABASTO/REABASTO.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/batch_service.dart';

class PvImportarEntradaScreen extends StatefulWidget {
  @override
  _PvImportarEntradaScreenState createState() => _PvImportarEntradaScreenState();
}

class _PvImportarEntradaScreenState extends State<PvImportarEntradaScreen> {
  final TextEditingController _jsonCtrl = TextEditingController();
  bool _procesando = false;
  Map<String, dynamic>? _resultado;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];
  // PV operativo: asignación de hoy (AuthService) con respaldo al fijo.
  int get _pvId {
    final a = context.read<AuthService>().currentUser;
    return (a?['punto_venta_id_actual'] as int?) ?? (a?['punto_venta_id'] as int?) ?? 2;
  }

  Future<void> _importar() async {
    if (_jsonCtrl.text.trim().isEmpty) { _snack('Pega el JSON recibido', Colors.orange); return; }
    setState(() { _procesando = true; _resultado = null; });
    final db = context.read<DatabaseHelper>();
    try {
      final res = await BatchService.importarBatch(db: await db.database, jsonContenido: _jsonCtrl.text.trim());
      if (res['exito'] != true) { setState(() { _procesando = false; _resultado = res; }); _snack('Error: ${res['error']}', Colors.red); return; }
      final tipo = res['tipo'] as String;
      final payload = res['payload'] as Map<String, dynamic>;
      final db2 = await db.database;
      final miCodigo = (await db2.query('puntos_venta', where: 'id = ?', whereArgs: [_pvId])).first['codigo'];
      if (res['origen'] != null && tipo != 'MAESTRO' && (payload['items'] != null)) { /* destino ya validado por header en aplicar */ }
      if (tipo == 'MAESTRO') {
        final r = await BatchService.aplicarBatchMaestro(db2, payload, _pvId, _hoy);
        setState(() { _procesando = false; _resultado = {'exito': true, 'tipo': tipo, 'detalle': r}; });
        _snack('MAESTRO aplicado · ${r['personal']} personas · ${r['stock']} uds', Colors.green);
      } else {
        final items = (payload['items'] as List?) ?? [];
        int total = 0;
        await db2.transaction((txn) async {
          for (final item in items) {
            final prodId = item['producto_id'] as int; final cant = (item['cantidad'] as num).toInt(); if (cant <= 0) continue;
            final ex = await txn.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [prodId, _pvId, _hoy]);
            if (ex.isEmpty) { await txn.insert('inventario', {'producto_id': prodId, 'punto_venta_id': _pvId, 'stock': cant, 'fecha': _hoy}); } else { await txn.update('inventario', {'stock': ((ex.first['stock'] as num?)?.toInt() ?? 0) + cant}, where: 'id = ?', whereArgs: [ex.first['id']]); }
            total += cant;
          }
        });
        setState(() { _procesando = false; _resultado = {'exito': true, 'tipo': tipo, 'total_items': total}; });
        _snack('$total uds sumadas al stock', Colors.green);
      }
      await db.getProductos();
    } catch (e) {
      setState(() { _procesando = false; _resultado = {'exito': false, 'error': e.toString()}; });
      _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RECIBIR ENTRADA / MAESTRO'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('PEGA EL JSON DEL BATCH', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('ABASTO/REABASTO suman stock. MAESTRO carga personal, asignaciones, productos, categorías, precios y parámetros.', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 15),
        Container(height: 300, decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: Colors.yellow)), padding: const EdgeInsets.all(10), child: TextField(controller: _jsonCtrl, maxLines: null, expands: true, keyboardType: TextInputType.multiline, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: const InputDecoration(border: InputBorder.none, hintText: '{"header": {...}, "payload": {...}}', hintStyle: TextStyle(color: Colors.white38, fontSize: 11)))),
        const SizedBox(height: 15),
        _procesando ? const Center(child: CircularProgressIndicator(color: Colors.yellow)) : ElevatedButton.icon(onPressed: _importar, icon: const Icon(Icons.download, color: Colors.black), label: const Text('RECIBIR E IMPORTAR'), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.yellow, foregroundColor: Colors.black)),
        if (_resultado != null) ...[
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (_resultado!['exito'] == true ? Colors.green : Colors.red).withOpacity(0.2), border: Border.all(color: _resultado!['exito'] == true ? Colors.green : Colors.red), borderRadius: BorderRadius.circular(8)),
            child: Text(_resultado!['exito'] == true ? 'IMPORTADO: ${_resultado!['tipo']}\n${_resultado!['detalle'] ?? _resultado!['total_items'] ?? ''}' : 'ERROR: ${_resultado!['error']} ${_resultado!['detalle'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12))),
        ],
      ])),
    );
  }
}