import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class CierreCajaScreen extends StatefulWidget {
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  double _totalVentas = 0.0;
  int _cantidadTransacciones = 0;
  bool _isLoading = true;

  // ID del punto de venta actual (debe coincidir con el de ventas)
  final int _puntoVentaId = 2;

  @override
  void initState() {
    super.initState();
    _cargarResumenCaja();
  }

  Future<void> _cargarResumenCaja() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Consultar ventas de hoy para este punto de venta
      final ventas = await db.consultar(
        'ventas',
        where: 'fecha LIKE ? AND punto_venta_id = ?',
        whereArgs: ['$hoy%', _puntoVentaId],
      );

      double suma = 0.0;
      for (var v in ventas) {
        suma += (v['monto_total'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _totalVentas = suma;
          _cantidadTransacciones = ventas.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar resumen: $e')),
        );
      }
    }
  }

  // --- FUNCIÓN REAL DE EXPORTACIÓN ---
  Future<void> _exportarMIG(BuildContext context) async {
    try {
      // 1. Cerrar la base de datos temporalmente para asegurar que los datos estén en el archivo principal
      final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
      final db = await dbHelper.database;
      await db.close();

      // 2. Obtener la ruta de la base de datos
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'eltonel.db'); 
      final dbFile = File(path);

      if (!await dbFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró la base de datos')),
        );
        return;
      }

      // 3. Copiar a un archivo temporal con la fecha actual
      final directory = await getTemporaryDirectory();
      final fecha = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final exportPath = '${directory.path}/MIG_ElTonel_$fecha.db';
      
      // Copiamos los archivos. En Android, sqflite a veces genera archivos -wal y -shm
      await dbFile.copy(exportPath);
      
      // Si existen los archivos WAL y SHM, los adjuntamos también (para no perder datos recientes)
      final walFile = File('$path-wal');
      if (await walFile.exists()) {
        await walFile.copy('$exportPath-wal');
      }
      final shmFile = File('$path-shm');
      if (await shmFile.exists()) {
        await shmFile.copy('$exportPath-shm');
      }

      // 4. Compartir por WhatsApp usando share_plus
      await Share.shareXFiles(
        [XFile(exportPath)],
        text: 'Cierre de turno El Tonel - $fecha\nTotal: S/ ${_totalVentas.toStringAsFixed(2)}\nTransacciones: $_cantidadTransacciones',
      );
      
      // 5. Opcional: reabrir la base de datos después de compartir
      // await dbHelper.database; 
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fechaHoy = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Caja - El Tonel'),
        backgroundColor: Colors.orange,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Resumen: $fechaHoy',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Transacciones:', style: TextStyle(fontSize: 18)),
                              Text('$_cantidadTransacciones', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 30, thickness: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL EN CAJA:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(
                                'S/ ${_totalVentas.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  const Text(
                    'Al cerrar el turno, la app generará el archivo de la base de datos y se abrirá WhatsApp para enviarlo al administrador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  
                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 90),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: () async {
                        final bool? confirmar = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('¿Cerrar Turno?'),
                            content: const Text('Se enviará el archivo MIG a WhatsApp y no podrás hacer más ventas hasta que el admin reinicie el día.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('CERRAR Y ENVIAR', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirmar == true) {
                          await _exportarMIG(context);
                        }
                      },
                      icon: const Icon(Icons.send, size: 40),
                      label: const Text(
                        'CERRAR TURNO\nY ENVIAR MIG',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}