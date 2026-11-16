import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class CierreCajaScreen extends StatefulWidget {
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  double _totalVentas = 0.0;
  int _cantidadTransacciones = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarResumenCaja();
  }

  Future<void> _cargarResumenCaja() async {
    setState(() {
      _isLoading = true;
    });

    // AQUÍ DEBES CONECTAR CON TU BASE DE DATOS SQLITE
    // Ejemplo:
    // final db = await DatabaseHelper.instance.database;
    // final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // final ventas = await db.query('ventas', where: 'fecha = ?', whereArgs: [hoy]);
    // _totalVentas = ventas.fold(0, (sum, item) => sum + (item['total'] as num));
    // _cantidadTransacciones = ventas.length;

    // Simulación temporal para que la pantalla cargue
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      _totalVentas = 0.0; // REEMPLAZA POR TU TOTAL REAL
      _cantidadTransacciones = 0; // REEMPLAZA POR TU CONTEO REAL
      _isLoading = false;
    });
  }

  // --- FUNCIÓN REAL DE EXPORTACIÓN ---
  Future<void> _exportarMIG(Context) async {
    try {
      // 1. Obtener la ruta de la base de datos (CAMBIA 'eltonel.db' por el nombre real de tu BD)
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'eltonel.db'); 
      final dbFile = File(path);

      if (!await dbFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró la base de datos')),
        );
        return;
      }

      // 2. Copiar a un archivo temporal con la fecha actual
      final directory = await getTemporaryDirectory();
      final fecha = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final exportPath = '${directory.path}/MIG_ElTonel_$fecha.db';
      await dbFile.copy(exportPath);

      // 3. Compartir por WhatsApp usando share_plus
      await Share.shareXFiles(
        [XFile(exportPath)],
        text: 'Cierre de turno El Tonel - $fecha',
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
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
                          // Llama a la función real de exportación
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