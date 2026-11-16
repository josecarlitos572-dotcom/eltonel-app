import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class AdminImportarDbScreen extends StatefulWidget {
  @override
  _AdminImportarDbScreenState createState() => _AdminImportarDbScreenState();
}

class _AdminImportarDbScreenState extends State<AdminImportarDbScreen> {
  bool _procesando = false;
  String _status = 'Selecciona el archivo .db que te envió el vendedor.';
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

    File? tempFile;
    Database? dbExterna;

    try {
      final originalFile = File(result.files.single.path!);
      
      // Copiamos a un directorio temporal para no bloquear el archivo original
      final tempDir = await getTemporaryDirectory();
      tempFile = File(p.join(tempDir.path, 'import_temp.db'));
      if (await tempFile.exists()) await tempFile.delete();
      await originalFile.copy(tempFile.path);

      // Abrimos la base de datos externa en modo lectura
      dbExterna = await openDatabase(tempFile.path, readOnly: true);

      // Verificamos que sea una BD de El Tonel
      final tablas = await dbExterna.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='ventas'");
      if (tablas.isEmpty) {
        throw Exception('El archivo no es una base de datos válida de El Tonel.');
      }

      setState(() => _status = 'Leyendo ventas...');

      // 1. Leer Ventas
      final ventas = await dbExterna.query('ventas');
      final dbLocal = Provider.of<DatabaseHelper>(context, listen: false);
      final db = await dbLocal.database;

      await db.transaction((txn) async {
        for (var v in ventas) {
          // Verificar si la venta ya existe (por fecha y monto exacto para evitar duplicados)
          final existe = await txn.query('ventas',
              where: 'fecha = ? AND monto_total = ? AND punto_venta_id = ?',
              whereArgs: [v['fecha'], v['monto_total'], v['punto_venta_id']]);
          
          if (existe.isEmpty) {
            // Insertamos la venta
            final nuevoId = await txn.insert('ventas', v);
            _ventasImportadas++;

            // 2. Leer y migrar el detalle de esa venta
            final detalles = await dbExterna!.query('detalle_venta',
                where: 'venta_id = ?', whereArgs: [v['id']]);
            
            for (var d in detalles) {
              final nuevoDetalle = Map<String, dynamic>.from(d);
              nuevoDetalle['venta_id'] = nuevoId; // Reasignar al nuevo ID
              nuevoDetalle.remove('id'); // Quitar ID viejo para que se autoincremente
              await txn.insert('detalle_venta', nuevoDetalle);
            }
          }
        }

        // 3. Leer Cierres de Caja
        setState(() => _status = 'Leyendo cierres de caja...');
        final cierres = await dbExterna!.query('cierres_caja');
        for (var c in cierres) {
          final existeCierre = await txn.query('cierres_caja',
              where: 'fecha = ? AND punto_venta_id = ?',
              whereArgs: [c['fecha'], c['punto_venta_id']]);
          
          if (existeCierre.isEmpty) {
            final nuevoCierre = Map<String, dynamic>.from(c);
            nuevoCierre.remove('id');
            await txn.insert('cierres_caja', nuevoCierre);
          }
        }

        // 4. Leer Gastos Internos
        setState(() => _status = 'Leyendo gastos...');
        final gastos = await dbExterna!.query('gastos_internos');
        for (var g in gastos) {
          final nuevoGasto = Map<String, dynamic>.from(g);
          nuevoGasto.remove('id');
          await txn.insert('gastos_internos', nuevoGasto);
        }
      });

      setState(() {
        _procesando = false;
        _status = '¡Importación exitosa! Se agregaron $_ventasImportadas ventas nuevas a la base de datos maestra.';
      });

    } catch (e) {
      setState(() {
        _procesando = false;
        _status = 'Error al importar: $e';
      });
    } finally {
      // Limpieza
      if (dbExterna != null) await dbExterna.close();
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IMPORTAR BASE DE DATOS'),
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
                  label: Text('SELECCIONAR ARCHIVO .DB'),
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