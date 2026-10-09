import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class PvImportarEntradaScreen extends StatefulWidget {
  @override
  _PvImportarEntradaScreenState createState() => _PvImportarEntradaScreenState();
}

class _PvImportarEntradaScreenState extends State<PvImportarEntradaScreen> {
  final TextEditingController _jsonCtrl = TextEditingController();
  bool _procesando = false;
  Map<String, dynamic>? _resultado;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  int get _pvId {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.currentUser?['punto_venta_id'] ?? 2;
  }

  Future<void> _importar() async {
    if (_jsonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pega el JSON recibido'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _procesando = true;
      _resultado = null;
    });

    final db = Provider.of<DatabaseHelper>(context, listen: false);

    try {
      final json = jsonDecode(_jsonCtrl.text.trim()) as Map<String, dynamic>;
      final header = json['header'] as Map<String, dynamic>?;
      final payload = json['payload'] as Map<String, dynamic>?;

      if (header == null || payload == null) {
        throw Exception('JSON inválido: falta header o payload');
      }

      final tipo = header['tipo'] as String? ?? '';
      final destino = header['destino'] as String? ?? '';
      final items = (payload['items'] as List?) ?? [];

      // Validar que este PV sea el destinatario
      final db2 = await db.database;
      final misDatos = await db2.query('puntos_venta',
          where: 'id = ?', whereArgs: [_pvId]);
      final miCodigo = misDatos.isNotEmpty ? misDatos.first['codigo'] : '';

      if (destino != miCodigo) {
        throw Exception('Este batch no es para tu punto ($miCodigo). Es para $destino.');
      }

      // Verificar si ya fue importado (por hash)
      final hashRecibido = header['hash'] as String? ?? '';
      final yaExiste = await db2.query('batches_recibidos',
          where: 'hash = ?', whereArgs: [hashRecibido]);
      if (yaExiste.isNotEmpty) {
        throw Exception('Este batch ya fue importado antes');
      }

      // Sumar stock
      int totalItems = 0;
      for (var item in items) {
        final prodId = item['producto_id'] as int;
        final cant = (item['cantidad'] as num).toInt();
        if (cant <= 0) continue;

        // Buscar si ya existe registro hoy
        final existente = await db2.query('inventario',
            where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?',
            whereArgs: [prodId, _pvId, _hoy]);

        if (existente.isEmpty) {
          await db2.insert('inventario', {
            'producto_id': prodId,
            'punto_venta_id': _pvId,
            'stock': cant,
            'fecha': _hoy,
          });
        } else {
          final actual = (existente.first['stock'] as num?)?.toInt() ?? 0;
          await db2.update('inventario', {'stock': actual + cant},
              where: 'id = ?', whereArgs: [existente.first['id']]);
        }

        totalItems += cant;
      }

      // Guardar registro del batch recibido
      await db2.insert('batches_recibidos', {
        'tipo': tipo,
        'origen': header['origen'] ?? '',
        'destino': destino,
        'periodo': header['periodo'] ?? _hoy,
        'secuencial': header['secuencial'] ?? 0,
        'hash': hashRecibido,
        'hash_anterior': header['hash_anterior'] ?? '',
        'contenido_json': _jsonCtrl.text.trim(),
        'fecha_generacion': header['fecha_generacion'] ?? '',
        'fecha_recepcion': DateTime.now().toIso8601String(),
        'estado': 'RECIBIDO',
      });

      // Auditoría
      await db2.insert('auditoria_cambios', {
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': _pvId,
        'usuario_nombre': 'PV $_pvId',
        'tabla_afectada': 'inventario',
        'accion': 'IMPORTAR_ENTRADA',
        'registro_id': _pvId,
        'datos_anteriores': null,
        'datos_nuevos': 'Tipo: $tipo | Origen: ${header['origen']} | Uds: $totalItems',
      });

      if (mounted) {
        setState(() {
          _procesando = false;
          _resultado = {
            'exito': true,
            'tipo': tipo,
            'origen': header['origen'] ?? '',
            'total_items': totalItems,
            'productos': items.length,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch importado. $totalItems unidades sumadas al stock.'),
            backgroundColor: Colors.green,
          ),
        );
        // Recargar cache
        await db.getProductos();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _procesando = false;
          _resultado = {'exito': false, 'error': e.toString()};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RECIBIR ENTRADA'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PEGA EL JSON RECIBIDO',
                style: TextStyle(
                    color: Colors.yellow,
                    fontFamily: 'CourierNew',
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            SizedBox(height: 8),
            Text(
                'Recibe batches de ABASTO, REABASTO o TRASLADO.\nSe suman al stock local.',
                style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'CourierNew',
                    fontSize: 11)),
            SizedBox(height: 15),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border.all(color: Colors.yellow),
              ),
              padding: EdgeInsets.all(10),
              child: TextField(
                controller: _jsonCtrl,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'CourierNew',
                    fontSize: 11),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '{"header": {...}, "payload": {...}}',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
            SizedBox(height: 15),
            _procesando
                ? Center(child: CircularProgressIndicator(color: Colors.yellow))
                : ElevatedButton.icon(
                    onPressed: _importar,
                    icon: Icon(Icons.download, color: Colors.black),
                    label: Text('RECIBIR E IMPORTAR'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      textStyle: TextStyle(
                          fontFamily: 'CourierNew',
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
            if (_resultado != null) ...[
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _resultado!['exito'] == true
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  border: Border.all(
                      color: _resultado!['exito'] == true
                          ? Colors.green
                          : Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _resultado!['exito'] == true
                            ? 'ENTRADA EXITOSA'
                            : 'ERROR',
                        style: TextStyle(
                            color: _resultado!['exito'] == true
                                ? Colors.green
                                : Colors.red,
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    SizedBox(height: 6),
                    if (_resultado!['exito'] == true) ...[
                      Text('Tipo: ${_resultado!['tipo']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 11)),
                      Text('Origen: ${_resultado!['origen']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 11)),
                      Text('Productos: ${_resultado!['productos']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 11)),
                      Text('Unidades sumadas: ${_resultado!['total_items']}',
                          style: TextStyle(
                              color: Colors.yellow,
                              fontFamily: 'CourierNew',
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ] else ...[
                      Text('${_resultado!['error']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}