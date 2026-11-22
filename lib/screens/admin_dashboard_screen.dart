import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../widgets/watermark_background.dart';
import 'admin_importar_db_screen.dart';
import 'admin_backup_screen.dart';
import 'admin_activar_vendedor_screen.dart';
import 'admin_generar_batch_screen.dart';
import 'mantenimiento/mantenimiento_menu_screen.dart';
import 'compra_screen.dart';
import 'cxc_screen.dart';
import 'rentabilidad_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _amber = Color(0xFFFFC107);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _card = Color(0xFF252525);
  static const Color _green = Color(0xFF43A047);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _orange = Color(0xFFFF9800);

  List<Map<String, dynamic>> _resumenPorPv = [];
  bool _cargando = true;
  double _totalVentas = 0.0, _totalGastos = 0.0;
  int _totalQuiebres = 0;
  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = context.read<DatabaseHelper>();
    final puntos = await db.getPuntosVenta();
    final resumen = <Map<String, dynamic>>[];
    double suma = 0.0;
    int tq = 0;
    for (var pv in puntos) {
      final pvId = pv['id'] as int;
      final ventas = await db.consultar('ventas', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$_hoy%', pvId]);
      final total = ventas.fold(0.0, (s, v) => s + ((v['monto_total'] as num?)?.toDouble() ?? 0.0));
      final cierre = await db.consultar('cierres_caja', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [_hoy, pvId]);
      final quiebres = await db.consultar('quiebres', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$_hoy%', pvId]);
      suma += total;
      tq += quiebres.length;
      resumen.add({'pv_id': pvId, 'pv_codigo': pv['codigo'], 'pv_nombre': pv['nombre'], 'ventas': total, 'cerrado': cierre.isNotEmpty, 'quiebres': quiebres.length});
    }
    final gastos = await db.consultar('gastos_internos', where: 'fecha LIKE ?', whereArgs: ['$_hoy%']);
    final tg = gastos.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0.0));
    if (mounted) setState(() { _resumenPorPv = resumen; _totalVentas = suma; _totalGastos = tg; _totalQuiebres = tq; _cargando = false; });
  }

  void _navegar(Widget p) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => p)); _cargar(); }

  void _confirmarLogout() {
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
              context.read<AuthService>().logout();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            child: const Text('SALIR', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCompacta(String t, double m, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _card, border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('S/ ${m.toStringAsFixed(2)}', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );

  Widget _tarjetaCompactaInt(String t, int v, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _card, border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('$v', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );

  Widget _botonAccionCompacto(String txt, IconData i, Color c, VoidCallback a) => Material(
    color: _card,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: a,
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
    if (_cargando) return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: _amber)));
    final utilidad = _totalVentas - _totalGastos;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WatermarkBackground(
        child: SafeArea(
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
                    _botonAccionCompacto('ACTIVAR VENDEDOR', Icons.play_circle_fill, _orange, () => _navegar(const AdminActivarVendedorScreen())),
                    _botonAccionCompacto('GENERAR BATCH', Icons.send, _amber, () => _navegar(const AdminGenerarBatchScreen())),
                    _botonAccionCompacto('IMPORTAR VENTAS', Icons.upload_file, _amber, () => _navegar(const AdminImportarDbScreen())),
                    _botonAccionCompacto('MANTENIMIENTO', Icons.build, Colors.blue, () => _navegar(const MantenimientoMenuScreen())),
                    _botonAccionCompacto('BACKUP SISTEMA', Icons.cloud_upload, _green, () => _navegar(const AdminBackupScreen())),
                    _botonAccionCompacto('CUENTAS X COBRAR', Icons.monetization_on, _orange, () => _navegar(const CxcScreen())),
                    _botonAccionCompacto('RENTABILIDAD', Icons.trending_up, _green, () => _navegar(const RentabilidadScreen())),
                    _botonAccionCompacto('REGISTRAR GASTO', Icons.shopping_cart, _red, () => _navegar(const CompraScreen())),
                  ],
                ),

                const SizedBox(height: 20),
                const Text('DETALLE POR PUNTO DE VENTA', style: TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 10),

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
      ),
    );
  }
}