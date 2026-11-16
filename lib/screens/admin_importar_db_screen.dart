import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class AdminImportarDbScreen extends StatefulWidget {
  @override
  _AdminImportarDbScreenState createState() => _AdminImportarDbScreenState();
}

class _AdminImportarDbScreenState extends State<AdminImportarDbScreen> {
  bool _procesando = false;
  String _status = 'Selecciona el archivo JSON que te envió el vendedor.';
  int _ventasImportadas = 0;

  Future<void> _seleccionarEImportar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _procesando = true;
      _status = 'Abriendo archivo...';
      _ventasImportadas = 0;
    });

    try {
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      // Validar que sea un archivo de cierre
      if (json['tipo'] != 'CIERRE_DIA') {
        throw Exception('El archivo no es un Cierre de Día válido.');
      }

      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) throw Exception('JSON sin datos (data).');

      final ventas = (data['ventas'] as List?) ?? [];
      final detalles = (data['detalles'] as List?) ?? [];
      final cierres = (data['cierres'] as List?) ?? [];
      final mermas = (data['mermas'] as List?) ?? [];

      final dbLocal = Provider.of<DatabaseHelper>(context, listen: false);
      final db = await dbLocal.database;

      setState(() => _status = 'Importando datos...');

      await db.transaction((txn) async {
        // 1. Insertar Ventas (evitando duplicados por ID y fecha)
        for (var v in ventas) {
          final existe = await txn.query('ventas',
              where: 'id = ? AND fecha = ?',
              whereArgs: [v['id'], v['fecha']]);
          
          if (existe.isEmpty) {
            await txn.insert('ventas', Map<String, dynamic>.from(v));
            _ventasImportadas++;
          }
        }

        // 2. Insertar Detalles
        for (var d in detalles) {
          final existe = await txn.query('detalle_venta',
              where: 'id = ?', whereArgs: [d['id']]);
          if (existe.isEmpty) {
            await txn.insert('detalle_venta', Map<String, dynamic>.from(d));
          }
        }

        // 3. Insertar Cierres de Caja
        for (var c in cierres) {
          final existe = await txn.query('cierres_caja',
              where: 'fecha = ? AND punto_venta_id = ?',
              whereArgs: [c['fecha'], c['punto_venta_id']]);
          if (existe.isEmpty) {
            await txn.insert('cierres_caja', Map<String, dynamic>.from(c));
          }
        }

        // 4. Insertar Mermas (Quiebres)
        for (var m in mermas) {
          final existe = await txn.query('quiebres',
              where: 'fecha = ? AND punto_venta_id = ? AND producto_id = ?',
              whereArgs: [m['fecha'], m['punto_venta_id'], m['producto_id']]);
          if (existe.isEmpty) {
            await txn.insert('quiebres', Map<String, dynamic>.from(m));
          }
        }
      });

      setState(() {
        _procesando = false;
        _status = '¡Importación exitosa! Se agregaron $_ventasImportadas ventas nuevas a tu base de datos.';
      });

    } catch (e) {
      setState(() {
        _procesando = false;
        _status = 'Error al importar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IMPORTAR CIERRE (JSON)'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 80, color: Colors.yellow),
              SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CourierNew',
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 30),
              if (_procesando)
                CircularProgressIndicator(color: Colors.yellow)
              else
                ElevatedButton.icon(
                  onPressed: _seleccionarEImportar,
                  icon: Icon(Icons.folder_open, color: Colors.black),
                  label: Text('SELECCIONAR ARCHIVO .JSON'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 60),
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    textStyle: TextStyle(
                      fontFamily: 'CourierNew',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}