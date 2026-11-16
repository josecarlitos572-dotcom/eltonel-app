import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class AdminBackupScreen extends StatefulWidget {
  @override
  _AdminBackupScreenState createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<AdminBackupScreen> {
  bool _procesando = false;
  String? _rutaBackup;
  String? _nombreArchivo;

  // FUNCIÓN DE GENERACIÓN (Mantenida y mejorada)
  Future<void> _generarBackup() async {
    setState(() => _procesando = true);

    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final db2 = await db.database;

      final Map<String, dynamic> backup = {
        'metadata': {
          'fecha_generacion': DateTime.now().toIso8601String(),
          'usuario_id': auth.currentUser?['id'],
          'usuario_nombre': auth.currentUser?['nombres'] ?? '',
          'version_bd': 12,
        },
      };

      final tablas = [
        'puntos_venta', 'categorias_producto', 'categorias_gasto', 'productos',
        'precios', 'personal', 'clientes', 'inventario', 'ventas',
        'detalle_venta', 'gastos_internos', 'cierres_caja', 'aperturas_caja',
        'transferencias', 'cuentas_por_cobrar', 'cobros', 'quiebres',
        'batches_generados', 'batches_recibidos', 'asignaciones_diarias',
        'parametros', 'auditoria_cambios',
      ];

      for (var tabla in tablas) {
        final data = await db2.query(tabla);
        backup[tabla] = data;
      }

      final jsonStr = jsonEncode(backup);

      final dir = await getApplicationDocumentsDirectory();
      final fecha = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-')
          .replaceAll('T', '_');
      final nombre = 'eltonel_backup_$fecha.json';
      final file = File('${dir.path}/$nombre');
      await file.writeAsString(jsonStr);

      await db2.insert('auditoria_cambios', {
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': auth.currentUser?['id'],
        'usuario_nombre': auth.currentUser?['nombres'] ?? '',
        'tabla_afectada': 'sistema',
        'accion': 'BACKUP_GENERADO',
        'registro_id': 0,
        'datos_anteriores': null,
        'datos_nuevos': 'Archivo: $nombre',
      });

      if (mounted) {
        setState(() {
          _rutaBackup = file.path;
          _nombreArchivo = nombre;
          _procesando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup generado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _compartirBackup() async {
    if (_rutaBackup == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_rutaBackup!)],
        subject: 'Backup El Tonel',
        text: 'Backup de base de datos generado desde la app',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- NUEVA FUNCIÓN DE RESTAURACIÓN ---
  Future<void> _restaurarBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('¿RESTAURAR BACKUP?',
            style: TextStyle(color: Colors.red, fontFamily: 'CourierNew')),
        content: Text(
            'ADVERTENCIA:\nEsto borrará TODOS los datos actuales de la aplicación y los reemplazará por los del archivo JSON que selecciones.\n\n¿Estás seguro?',
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('CANCELAR', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('SÍ, RESTAURAR', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    setState(() => _procesando = true);
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);

    try {
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      final Map<String, dynamic> backup = jsonDecode(jsonStr) as Map<String, dynamic>;

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        // 1. Vaciar todas las tablas actuales
        final tablas = [
          'puntos_venta', 'categorias_producto', 'categorias_gasto', 'productos',
          'precios', 'personal', 'clientes', 'inventario', 'ventas',
          'detalle_venta', 'gastos_internos', 'cierres_caja', 'aperturas_caja',
          'transferencias', 'cuentas_por_cobrar', 'cobros', 'quiebres',
          'batches_generados', 'batches_recibidos', 'asignaciones_diarias',
          'parametros', 'auditoria_cambios',
        ];
        for (var t in tablas) {
          await txn.delete(t);
        }

        // 2. Insertar los datos del JSON
        for (var t in tablas) {
          if (backup.containsKey(t) && backup[t] is List) {
            for (var row in (backup[t] as List)) {
              await txn.insert(t, Map<String, dynamic>.from(row));
            }
          }
        }
      });

      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup restaurado con éxito. Reinicia la app.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BACKUP DE SISTEMA'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.cloud_upload, color: Colors.yellow, size: 80),
            SizedBox(height: 20),
            Text('GESTIÓN DE RESPALDO',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.yellow,
                    fontFamily: 'CourierNew',
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            SizedBox(height: 10),
            Text(
              'Exporta o restaura la base de datos completa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white70, fontFamily: 'CourierNew', fontSize: 12),
            ),
            SizedBox(height: 30),
            _procesando
                ? Center(child: CircularProgressIndicator(color: Colors.yellow))
                : Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _generarBackup,
                      icon: Icon(Icons.play_arrow, color: Colors.black),
                      label: Text('GENERAR BACKUP'),
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
                    SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _restaurarBackup,
                      icon: Icon(Icons.restore, color: Colors.white),
                      label: Text('RESTAURAR DESDE JSON'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 55),
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ],
                ),
            if (_nombreArchivo != null) ...[
              SizedBox(height: 30),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 40),
                    SizedBox(height: 8),
                    Text('BACKUP GENERADO',
                        style: TextStyle(
                            color: Colors.green,
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    SizedBox(height: 6),
                    Text(_nombreArchivo!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CourierNew',
                            fontSize: 10)),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _compartirBackup,
                icon: Icon(Icons.share, color: Colors.black),
                label: Text('COMPARTIR BACKUP'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 55),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  textStyle: TextStyle(
                      fontFamily: 'CourierNew',
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}