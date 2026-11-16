import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Importa tu ExportService (o la ruta donde tengas la función de exportar)
// import '../services/export_service.dart'; 

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
    // Ejemplo con tu DatabaseHelper:
    // final db = await DatabaseHelper.instance.database;
    // final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // final ventas = await db.query('ventas', where: 'fecha = ?', whereArgs: [hoy]);
    // _totalVentas = ventas.fold(0, (sum, item) => sum + (item['total'] as num));
    // _cantidadTransacciones = ventas.length;

    // Simulación temporal para ver la UI
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _totalVentas = 0.0; // Pon aquí tu variable real
      _cantidadTransacciones = 0; // Pon aquí tu variable real
      _isLoading = false;
    });
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
                          // AQUÍ LLAMAS A TU FUNCIÓN DE EXPORTAR
                          // Ejemplo: await ExportService().exportarMIGyEnviar(context);
                          
                          // Simulación de exportación exitosa:
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Archivo MIG generado y enviado a WhatsApp.')),
                            );
                          }
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