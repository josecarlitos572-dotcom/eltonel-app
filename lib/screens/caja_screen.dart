import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';
// Importa tu DatabaseHelper para traer las ventas del día
// import '../services/database_helper.dart';

class CajaScreen extends StatefulWidget {
  @override
  _CajaScreenState createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
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
    // final ventas = await db.query('ventas', where: 'fecha = ?', whereArgs: [hoy]);
    // _totalVentas = ventas.fold(0, (sum, item) => sum + item['total']);
    // _cantidadTransacciones = ventas.length;

    // Simulación de datos para que veas la interfaz funcionando
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _totalVentas = 450.50; // Reemplaza esto con el total real de la BD
      _cantidadTransacciones = 35; // Reemplaza esto con el conteo real
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String fechaHoy = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja - El Tonel'),
        backgroundColor: Colors.orange,
        automaticallyImplyLeading: false, // Evita que el vendedor se salga de la pantalla
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TARJETA DE RESUMEN ---
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Resumen del Día: $fechaHoy',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ventas realizadas:', style: TextStyle(fontSize: 18)),
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

                  // --- INSTRUCCIONES ---
                  const Text(
                    'Al cerrar el turno, la app generará el archivo de la base de datos y se abrirá WhatsApp para que lo envíes al administrador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  
                  const Spacer(),

                  // --- BOTÓN GIGANTE DE CIERRE ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 90), // Botón enorme para dedos con guantes
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: () async {
                        // Confirmación antes de cerrar para evitar falsos toques
                        final bool? confirmar = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('¿Cerrar Turno?'),
                            content: const Text('Se enviará el archivo MIG a tu WhatsApp y no podrás hacer más ventas hasta que el admin reinicie el día.'),
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
                          // Ejecuta el servicio de exportación
                          await ExportService().exportarMIGyEnviar(context);
                          
                          // Opcional: Aquí podrías forzar el cierre de sesión o bloquear la pantalla
                          if (mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Turno Cerrado'),
                                content: const Text('El archivo ha sido enviado. Por favor, entrega el celular al administrador.'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      // Aquí podrías navegar a una pantalla de bloqueo
                                    },
                                    child: const Text('Entendido'),
                                  )
                                ],
                              ),
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