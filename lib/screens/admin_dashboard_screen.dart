import 'package:flutter/material.dart'; // 1. Librería principal de Flutter.
import 'package:provider/provider.dart'; // 2. Gestor de estado para acceder a servicios.
import '../services/database_helper.dart'; // 3. Servicio de base de datos local.
import '../services/auth_service.dart'; // 4. Servicio de autenticación.
import '../widgets/watermark_overlay.dart'; // 5. ¡IMPORTACIÓN CORRECTA de la marca de agua!
import 'admin_importar_db_screen.dart'; // 6. Pantalla de importación.
import 'admin_backup_screen.dart'; // 7. Pantalla de backup.
import 'admin_activar_vendedor_screen.dart'; // 8. Pantalla de activación de vendedores.
import 'admin_generar_batch_screen.dart'; // 9. Pantalla de generación de batches.
import 'mantenimiento/mantenimiento_menu_screen.dart'; // 10. Menú de mantenimiento.
import 'compra_screen.dart'; // 11. Pantalla de registro de gastos.
import 'cxc_screen.dart'; // 12. Pantalla de cuentas por cobrar.
import 'rentabilidad_screen.dart'; // 13. Pantalla de rentabilidad.
import 'login_screen.dart'; // 14. Pantalla de inicio de sesión.

class AdminDashboardScreen extends StatefulWidget { // 15. Pantalla principal del administrador (con estado).
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState(); // 16. Crea el estado de la pantalla.
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // 17. Definición de colores personalizados para la temática oscura/ámbar.
  static const Color _amber = Color(0xFFFFC107);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _card = Color(0xFF252525);
  static const Color _green = Color(0xFF43A047);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _orange = Color(0xFFFF9800);

  List<Map<String, dynamic>> _resumenPorPv = []; // 18. Lista para guardar el resumen por punto de venta.
  bool _cargando = true; // 19. Bandera para mostrar el indicador de carga.
  double _totalVentas = 0.0, _totalGastos = 0.0; // 20. Totales del día.
  int _totalQuiebres = 0; // 21. Contador de quiebres de stock.
  String get _hoy => DateTime.now().toIso8601String().split('T')[0]; // 22. Obtiene la fecha de hoy en formato YYYY-MM-DD.

  @override
  void initState() {
    super.initState(); // 23. Llama al initState de la clase padre.
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar()); // 24. Ejecuta _cargar() después de que la pantalla se dibuje por primera vez.
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true); // 25. Activa el estado de carga.
    final db = context.read<DatabaseHelper>(); // 26. Obtiene la instancia de la base de datos.
    final puntos = await db.getPuntosVenta(); // 27. Consulta todos los puntos de venta.
    final resumen = <Map<String, dynamic>>[]; // 28. Lista temporal para el resumen.
    double suma = 0.0; // 29. Acumulador de ventas totales.
    int tq = 0; // 30. Acumulador de quiebres totales.
    
    for (var pv in puntos) { // 31. Itera sobre cada punto de venta.
      final pvId = pv['id'] as int; // 32. Obtiene el ID del punto de venta.
      // 33. Consulta las ventas de hoy para este punto de venta.
      final ventas = await db.consultar('ventas', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$_hoy%', pvId]);
      // 34. Suma los montos totales de las ventas.
      final total = ventas.fold(0.0, (s, v) => s + ((v['monto_total'] as num?)?.toDouble() ?? 0.0));
      // 35. Consulta si ya se registró el cierre de caja hoy.
      final cierre = await db.consultar('cierres_caja', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [_hoy, pvId]);
      // 36. Consulta los quiebres de stock de hoy.
      final quiebres = await db.consultar('quiebres', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$_hoy%', pvId]);
      
      suma += total; // 37. Acumula el total de ventas.
      tq += quiebres.length; // 38. Acumula la cantidad de quiebres.
      // 39. Agrega el resumen de este punto de venta a la lista.
      resumen.add({'pv_id': pvId, 'pv_codigo': pv['codigo'], 'pv_nombre': pv['nombre'], 'ventas': total, 'cerrado': cierre.isNotEmpty, 'quiebres': quiebres.length});
    }
    
    // 40. Consulta todos los gastos internos de hoy.
    final gastos = await db.consultar('gastos_internos', where: 'fecha LIKE ?', whereArgs: ['$_hoy%']);
    // 41. Suma los montos de los gastos.
    final tg = gastos.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0.0));
    
    // 42. Actualiza el estado con los datos calculados, solo si el widget sigue montado en la pantalla.
    if (mounted) {
      setState(() { 
        _resumenPorPv = resumen; 
        _totalVentas = suma; 
        _totalGastos = tg; 
        _totalQuiebres = tq; 
        _cargando = false; 
      });
    }
  }

  void _navegar(Widget p) async { // 43. Función para navegar a otra pantalla y recargar los datos al regresar.
    await Navigator.push(context, MaterialPageRoute(builder: (_) => p)); // 44. Navega a la pantalla.
    _cargar(); // 45. Recarga los datos al volver.
  }

  void _confirmarLogout() { // 46. Muestra un diálogo de confirmación para cerrar sesión.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('¿Cerrar sesión?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Volverás a la pantalla de inicio de sesión.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, minimumSize: const Size(80, 36)),
            onPressed: () {
              context.read<AuthService>().logout(); // 47. Ejecuta el logout en el servicio de autenticación.
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); // 48. Redirige al login y limpia el historial.
            },
            child: const Text('SALIR', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // 49. Widget reutilizable para mostrar tarjetas compactas con montos.
  Widget _tarjetaCompacta(String t, double m, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _card, border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('S/ ${m.toStringAsFixed(2)}', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );

  // 50. Widget reutilizable para mostrar tarjetas compactas con números enteros.
  Widget _tarjetaCompactaInt(String t, int v, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _card, border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('$v', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );

  // 51. Widget reutilizable para botones de acción compactos con ícono y texto.
  Widget _botonAccionCompacto(String txt, IconData i, Color c, VoidCallback a) => Material(
    color: _card,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: a, // 52. Ejecuta la acción al hacer tap.
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.4), width: 1)),
        child: Row(
          children: [
            Icon(i, size: 20, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(txt, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: c))),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // 53. Si está cargando, muestra un Scaffold con un indicador de progreso.
    if (_cargando) return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: _amber)));
    
    final utilidad = _totalVentas - _totalGastos; // 54. Calcula la utilidad del día.

    return Scaffold(
      backgroundColor: Colors.transparent, // 55. Fondo transparente para que se vea la marca de agua.
      // 56. ¡CORRECCIÓN CLAVE! Usamos un Stack para superponer la marca de agua sobre el contenido.
      body: Stack(
        children: [
          // 57. PRIMERA CAPA: El contenido principal de la pantalla.
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER COMPACTO
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DASHBOARD', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            Text('Resumen del día', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.refresh, color: _amber, size: 22), onPressed: _cargar, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      const SizedBox(width: 12),
                      IconButton(icon: const Icon(Icons.logout, color: _amber, size: 22), onPressed: _confirmarLogout, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // TARJETAS DE RESUMEN (3 en fila)
                  Row(
                    children: [
                      Expanded(child: _tarjetaCompacta('VENTAS', _totalVentas, _green)),
                      const SizedBox(width: 8),
                      Expanded(child: _tarjetaCompacta('GASTOS', _totalGastos, _red)),
                      const SizedBox(width: 8),
                      Expanded(child: _tarjetaCompacta('UTILIDAD', utilidad, utilidad >= 0 ? _amber : _red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _tarjetaCompactaInt('QUIEBRES', _totalQuiebres, _orange)),
                      const SizedBox(width: 8),
                      Expanded(child: _tarjetaCompactaInt('PUNTOS', _resumenPorPv.length, Colors.blue)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text('ACCIONES RÁPIDAS', style: TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 10),

                  // GRID DE ACCIONES (2 columnas, compacto)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.5,
                    children: [
                      _botonAccionCompacto('ACTIVAR VENDEDOR', Icons.play_circle_fill, _orange, () => _navegar(AdminActivarVendedorScreen())),
                      _botonAccionCompacto('GENERAR BATCH', Icons.send, _amber, () => _navegar(AdminGenerarBatchScreen())),
                      _botonAccionCompacto('IMPORTAR VENTAS', Icons.upload_file, _amber, () => _navegar(AdminImportarDbScreen())),
                      _botonAccionCompacto('MANTENIMIENTO', Icons.build, Colors.blue, () => _navegar(MantenimientoMenuScreen())),
                      _botonAccionCompacto('BACKUP SISTEMA', Icons.cloud_upload, _green, () => _navegar(AdminBackupScreen())),
                      _botonAccionCompacto('CUENTAS X COBRAR', Icons.monetization_on, _orange, () => _navegar(CxcScreen())),
                      _botonAccionCompacto('RENTABILIDAD', Icons.trending_up, _green, () => _navegar(RentabilidadScreen())),
                      _botonAccionCompacto('REGISTRAR GASTO', Icons.shopping_cart, _red, () => _navegar(CompraScreen())),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text('DETALLE POR PUNTO DE VENTA', style: TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 10),

                  // 58. Lista de tarjetas con el detalle de cada punto de venta.
                  ..._resumenPorPv.map((r) {
                    final cerrado = r['cerrado'] as bool;
                    return Card(
                      color: _card,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: cerrado ? _green : Colors.grey,
                          radius: 16,
                          child: Icon(cerrado ? Icons.check : Icons.schedule, color: Colors.black, size: 16),
                        ),
                        title: Text('${r['pv_codigo']} - ${r['pv_nombre']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: Text(cerrado ? 'CIERRE REGISTRADO' : 'SIN CIERRE', style: TextStyle(color: cerrado ? _green : _orange, fontSize: 10)),
                        trailing: Text('S/ ${(r['ventas'] as double).toStringAsFixed(2)}', style: const TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          
          // 59. SEGUNDA CAPA: La marca de agua (va al final para quedar encima de todo).
          // IgnorePointer dentro de WatermarkOverlay asegura que los toques pasen a los botones de abajo.
          const WatermarkOverlay(
            text: 'El Tonel',
            opacity: 0.08,
            fontSize: 50.0,
          ),
        ], // 60. Cierre de la lista children del Stack.
      ), // 61. Cierre del Stack.
    ); // 62. Cierre del Scaffold.
  } // 63. Cierre del método build.
} // 64. Cierre de la clase _AdminDashboardScreenState.