import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import 'pv_cierre_inventario_screen.dart'; // Asegúrate de que esta ruta sea correcta

class CierreCajaScreen extends StatefulWidget {
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  double _totalVentas = 0.0;
  int _cantidadTransacciones = 0;
  bool _isLoading = true;
  int _puntoVentaId = 0;
  String _pvCodigo = '?';

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
      
      _puntoVentaId = auth.currentUser?['punto_venta_id_actual'] as int? ?? 0;
      
      final db2 = await db.database;
      final pvData = await db2.query('puntos_venta', where: 'id = ?', whereArgs: [_puntoVentaId]);
      if (pvData.isNotEmpty) {
        _pvCodigo = pvData.first['codigo'] as String? ?? 'PV$_puntoVentaId';
      }

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
      }
    }
  }

  Future<void> _exportarJSONyEnviar(BuildContext context) async {
    try {
      final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final usuarioId = auth.currentUser?['id'] as int? ?? 1;
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
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
      
      final ventasIds = await db.query('ventas', 
          columns: ['id'], 
          where: 'fecha LIKE ? AND punto_venta_id = ?', 
          whereArgs: ['$hoy%', _puntoVentaId]);
      
      List<int> ids = ventasIds.map((v) => v['id'] as int).toList();
      
      List<Map<String, dynamic>> detalles = [];
      if (ids.isNotEmpty) {
        final placeholders = List.filled(ids.length, '?').join(',');
        detalles = await db.query('detalle_venta', where: 'venta_id IN ($placeholders)', whereArgs: ids);
      }

      final ventas = await db.query('ventas', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$hoy%', _puntoVentaId]);
      final cierres = await db.query('cierres_caja', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [hoy, _puntoVentaId]);
      final mermas = await db.query('quiebres', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [hoy, _puntoVentaId]);
      final inventario = await db.query('inventario', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [hoy, _puntoVentaId]);

      final jsonExport = {
        'tipo': 'CIERRE_DIA',
        'fecha': hoy,
        'punto_venta_codigo': _pvCodigo,
        'data': {
          'ventas': ventas,
          'detalles': detalles,
          'cierres': cierres,
          'mermas': mermas,
          'inventario': inventario,
        }
      };

      final jsonStr = jsonEncode(jsonExport);
      
      final directory = await getTemporaryDirectory();
      final fileName = 'CIERRE_${_pvCodigo}_$hoy.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cierre El Tonel - $_pvCodigo - $hoy\nVentas: S/ ${_totalVentas.toStringAsFixed(2)}',
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
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFF1E1E1E),
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
                              const Text('Transacciones:', style: TextStyle(fontSize: 18, color: Colors.white)),
                              Text('$_cantidadTransacciones', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          const Divider(height: 30, thickness: 2, color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL EN CAJA:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
                    'Al cerrar el turno, la app generará el archivo JSON con las ventas, mermas y stock a cero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  
                  const Spacer(),

                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => PvCierreInventarioScreen()));
                      _cargarResumenCaja();
                    },
                    icon: const Icon(Icons.inventory, color: Colors.black),
                    label: const Text('HACER CONTEÍDO FÍSICO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                  ),

                  const SizedBox(height: 15),

                  ElevatedButton.icon(
                    onPressed: () async {
                      final bool? confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('¿Exportar Cierre?', style: TextStyle(color: Colors.white)),
                          content: const Text('Se generará el archivo JSON y se abrirá WhatsApp.', style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar', style: TextStyle(color: Colors.white))),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('EXPORTAR', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirmar == true) {
                        await _exportarJSONyEnviar(context);
                      }
                    },
                    icon: const Icon(Icons.send, size: 30, color: Colors.white),
                    label: const Text('EXPORTAR CIERRE (.JSON)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      minimumSize: const Size(double.infinity, 80),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}