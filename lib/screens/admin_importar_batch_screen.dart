import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/batch_service.dart';

class AdminImportarBatchScreen extends StatefulWidget {
  @override
  _AdminImportarBatchScreenState createState() => _AdminImportarBatchScreenState();
}

class _AdminImportarBatchScreenState extends State<AdminImportarBatchScreen> {
  final TextEditingController _jsonCtrl = TextEditingController();
  bool _procesando = false;
  Map<String, dynamic>? _resultado;

  Future<void> _importar() async {
    if (_jsonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pega el JSON del batch'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _procesando = true;
      _resultado = null;
    });

    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final db2 = await db.database;

    try {
      final res = await BatchService.importarBatch(
        db: db2,
        jsonContenido: _jsonCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _resultado = res;
          _procesando = false;
        });

        if (res['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Batch importado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['error']} - ${res['detalle']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _procesando = false;
          _resultado = {
            'exito': false,
            'error': 'EXCEPTION',
            'detalle': e.toString()
          };
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
        title: Text('IMPORTAR BATCH'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PEGA EL JSON RECIBIDO POR WHATSAPP',
                style: TextStyle(
                    color: Colors.yellow,
                    fontFamily: 'CourierNew',
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            SizedBox(height: 8),
            Text(
                'El sistema verificará el hash y la continuidad del batch antes de importarlo.',
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
                    icon: Icon(Icons.cloud_upload, color: Colors.black),
                    label: Text('IMPORTAR BATCH'),
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
                            ? 'IMPORTACIÓN EXITOSA'
                            : 'ERROR DE IMPORTACIÓN',
                        style: TextStyle(
                            color: _resultado!['exito'] == true
                                ? Colors.green
                                : Colors.red,
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    SizedBox(height: 6),
                    if (_resultado!['exito'] == true) ...[
                      Text('Batch ID: ${_resultado!['batch_id']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 11)),
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
                    ] else ...[
                      Text('Error: ${_resultado!['error']}',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CourierNew',
                              fontSize: 11)),
                      SizedBox(height: 4),
                      Text('${_resultado!['detalle'] ?? ''}',
                          style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'CourierNew',
                              fontSize: 10)),
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