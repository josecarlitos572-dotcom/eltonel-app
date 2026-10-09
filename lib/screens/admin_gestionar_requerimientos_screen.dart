import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class AdminGestionarRequerimientosScreen extends StatefulWidget {
  @override
  _AdminGestionarRequerimientosScreenState createState() =>
      _AdminGestionarRequerimientosScreenState();
}

class _AdminGestionarRequerimientosScreenState
    extends State<AdminGestionarRequerimientosScreen> {
  List<Map<String, dynamic>> _requerimientos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final db2 = await db.database;

    final reqs = await db2.query('batches_generados',
        where: 'tipo = ? AND estado = ?',
        whereArgs: ['REQUERIMIENTO', 'GENERADO'],
        orderBy: 'id DESC');

    if (mounted) {
      setState(() {
        _requerimientos = reqs;
        _cargando = false;
      });
    }
  }

  Future<void> _verDetalle(Map<String, dynamic> req) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(req['contenido_json'] as String);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON inválido'), backgroundColor: Colors.red),
      );
      return;
    }

    final header = json['header'] as Map<String, dynamic>? ?? {};
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    final items = (payload['items'] as List?) ?? [];

    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final productos = db.products;

    if (!mounted) return;

    final accion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('${header['codigo'] ?? 'REQ'}',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 14)),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Origen: ${header['origen'] ?? ''}',
                  style: TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 11)),
              Text('Destino: ${header['destino'] ?? ''}',
                  style: TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 11)),
              Divider(color: Colors.yellow),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (c, i) {
                    final item = items[i];
                    final prod = productos.firstWhere(
                      (p) => p['id'] == item['producto_id'],
                      orElse: () => {'codigo': '?', 'nombre': '?'},
                    );
                    return ListTile(
                      dense: true,
                      title: Text('${prod['codigo']} ${prod['nombre']}',
                          style: TextStyle(
                              color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                      trailing: Text('x${item['cantidad']}',
                          style: TextStyle(
                              color: Colors.yellow,
                              fontFamily: 'CourierNew',
                              fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'RECHAZAR'),
            child: Text('RECHAZAR', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'APROBAR'),
            child: Text('APROBAR', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (accion == 'APROBAR') {
      await _aprobarRequerimiento(req, items);
    } else if (accion == 'RECHAZAR') {
      await _rechazarRequerimiento(req);
    }
  }

  Future<void> _aprobarRequerimiento(
      Map<String, dynamic> req, List items) async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final db2 = await db.database;

    try {
      final header = jsonDecode(req['contenido_json'] as String)['header'];
      final origen = header['origen'] as String? ?? '';

      // Buscar ID del PV origen
      final pvData = await db2.query('puntos_venta',
          where: 'codigo = ?', whereArgs: [origen]);
      final origenId = pvData.isNotEmpty ? pvData.first['id'] as int : 0;

      // Crear traslado desde BASE al origen
      final itemsList = items
          .map((e) => {
                'producto_id': e['producto_id'],
                'cantidad': e['cantidad'],
              })
          .toList();

      await db.registrarTrasladoCompleto(
        origenId: 1, // BASE
        destinoId: origenId,
        usuarioId: auth.currentUser?['id'] ?? 1,
        items: itemsList,
        tipo: 'ABASTO',
      );

      // Marcar requerimiento como aprobado
      await db.actualizar('batches_generados', {
        'id': req['id'],
        'estado': 'APROBADO',
      });

      await db2.insert('auditoria_cambios', {
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': auth.currentUser?['id'],
        'usuario_nombre': auth.currentUser?['nombres'] ?? '',
        'tabla_afectada': 'batches_generados',
        'accion': 'REQUERIMIENTO_APROBADO',
        'registro_id': req['id'],
        'datos_anteriores': 'GENERADO',
        'datos_nuevos': 'APROBADO → traslado generado a $origen',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requerimiento aprobado'), backgroundColor: Colors.green),
      );

      _cargar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rechazarRequerimiento(Map<String, dynamic> req) async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final db2 = await db.database;

    try {
      await db.actualizar('batches_generados', {
        'id': req['id'],
        'estado': 'RECHAZADO',
      });

      await db2.insert('auditoria_cambios', {
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': auth.currentUser?['id'],
        'usuario_nombre': auth.currentUser?['nombres'] ?? '',
        'tabla_afectada': 'batches_generados',
        'accion': 'REQUERIMIENTO_RECHAZADO',
        'registro_id': req['id'],
        'datos_anteriores': 'GENERADO',
        'datos_nuevos': 'RECHAZADO',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requerimiento rechazado'), backgroundColor: Colors.orange),
      );

      _cargar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            title: Text('REQUERIMIENTOS'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('REQUERIMIENTOS (${_requerimientos.length})'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      backgroundColor: Colors.black,
      body: _requerimientos.isEmpty
          ? Center(
              child: Text('Sin requerimientos pendientes',
                  style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew')),
            )
          : ListView.builder(
              itemCount: _requerimientos.length,
              itemBuilder: (ctx, i) {
                final req = _requerimientos[i];

                String origen = '?';
                int itemsCount = 0;
                try {
                  final json = jsonDecode(req['contenido_json'] as String);
                  origen = json['header']['origen'] ?? '?';
                  itemsCount = (json['payload']['items'] as List).length;
                } catch (e) {}

                return Card(
                  color: Color(0xFF1A1A1A),
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.inbox, color: Colors.black, size: 20),
                    ),
                    title: Text('Desde: $origen',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    subtitle: Text('$itemsCount productos · ${req['fecha_generacion'] ?? ''}',
                        style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'CourierNew',
                            fontSize: 10)),
                    trailing: Icon(Icons.arrow_forward_ios,
                        color: Colors.yellow, size: 16),
                    onTap: () => _verDetalle(req),
                  ),
                );
              },
            ),
    );
  }
}