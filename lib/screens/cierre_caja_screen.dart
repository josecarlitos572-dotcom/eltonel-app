import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class CierreCajaScreen extends StatefulWidget {
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  double _totalVentas = 0.0;
  int _cantidadTransacciones = 0;
  bool _isLoading = true;
  int _puntoVentaId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarResumenCaja();
    });
  }

  Future<void> _cargarResumenCaja() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      
      _puntoVentaId = auth.currentUser?['punto_venta_id_actual'] as int? ?? 2;
      
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
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

  Future<void> _exportarMIG(BuildContext context) async {
    try {
      final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final usuarioId = auth.currentUser?['id'] as int? ?? 1;
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 1. Registrar el cierre en la base de datos ANTES de exportar
      await dbHelper.insertar('cierres_caja', {
        'fecha': hoy,
        'punto_venta_id': _puntoVentaId,
        'personal_id': usuarioId,
        'saldo_inicial': 0.0,
        'total_ventas': _totalVentas,
        'total_gastos_manuales': 0.0,
        'saldo_teorico': _totalVentas,
        'saldo_real_contado': _totalVentas,
        'diferencia': 0.0,
        'observaciones': 'Cierre generado por vendedor desde la app.',
      });

      final db = await dbHelper.database;
      await db.close();

      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, DatabaseHelper.dbName); 
      final dbFile = File(path);

      if (!await dbFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró la base de datos')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final fecha = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final exportPath = '${directory.path}/MIG_ElTonel_$fecha.db';
      
      await dbFile.copy(exportPath);
      
      final walFile = File('$path-wal');
      if (await walFile.exists()) {
        await walFile.copy('$exportPath-wal');
      }
      final shmFile = File('$path-shm');
      if (await shmFile.exists()) {
        await shmFile.copy('$exportPath-shm');
      }

      await Share.shareXFiles(
        [XFile(exportPath)],
        text: 'Cierre de turno El Tonel - $fecha\nPV: $_puntoVentaId\nTotal: S/ ${_totalVentas.toStringAsFixed(2)}\nTransacciones: $_cantidadTransacciones',
      );
      
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