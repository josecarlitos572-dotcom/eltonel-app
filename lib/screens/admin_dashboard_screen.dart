import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import 'admin_importar_db_screen.dart';
import 'admin_backup_screen.dart';
import 'admin_activar_vendedor_screen.dart';
import 'admin_generar_batch_screen.dart';
import 'mantenimiento/mantenimiento_menu_screen.dart';
import 'compra_screen.dart';
import 'cxc_screen.dart';
import 'rentabilidad_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _resumenPorPv = [];
  List<Map<String, dynamic>> _cierreHoy = [];
  bool _cargando = true;
  double _totalVentas = 0.0, _totalGastos = 0.0;
  int _totalQuiebres = 0;
  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _cargar()); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = context.read<DatabaseHelper>();
    final puntos = await db.getPuntosVenta();
    final resumen = <Map<String, dynamic>>[]; double suma = 0.0; int tq = 0;
    for (var pv in puntos) {
      final pvId = pv['id'] as int;
      final ventas = await db.consultar('ventas', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$_hoy%', pvId]);
      final total = ventas.fold(0.0, (s, v) => s + ((v['monto_total'] as num?)?.toDouble() ?? 0.0));
      final cierre = await db.consultar('cierres_caja', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [_hoy, pvId]);
      final quiebres = await db.consultar('quiebres', where: 'fecha LIKE ? AND punto_venta_id = ?', whereArgs: ['$_hoy%', pvId]);
      suma += total; tq += quiebres.length;
      resumen.add({'pv_id': pvId, 'pv_codigo': pv['codigo'], 'pv_nombre': pv['nombre'], 'ventas': total, 'cerrado': cierre.isNotEmpty, 'quiebres': quiebres.length});
    }
    final gastos = await db.consultar('gastos_internos', where: 'fecha LIKE ?', whereArgs: ['$_hoy%']);
    final tg = gastos.fold(0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0.0));
    final cierresHoy = await db.consultarCierresDelDia(_hoy);
    if (mounted) setState(() { _resumenPorPv = resumen; _cierreHoy = cierresHoy; _totalVentas = suma; _totalGastos = tg; _totalQuiebres = tq; _cargando = false; });
  }

  void _navegar(Widget p) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => p)); _cargar(); }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    final utilidad = _totalVentas - _totalGastos;
    return Scaffold(
      appBar: AppBar(title: const Text('DASHBOARD DEL DÍA'), backgroundColor: Colors.black, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)]),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('RESUMEN GENERAL — $_hoy', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _tarjeta('VENTAS', _totalVentas, Colors.green)), const SizedBox(width: 8), Expanded(child: _tarjeta('GASTOS', _totalGastos, Colors.red))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _tarjeta('UTILIDAD', utilidad, utilidad >= 0 ? Colors.yellow : Colors.red)), const SizedBox(width: 8), Expanded(child: _tarjetaInt('QUIEBRES', _totalQuiebres, Colors.orange))]),
        const SizedBox(height: 20),
        const Text('ACCIONES RÁPIDAS', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _botonAccion('ACTIVAR VENDEDOR', Icons.play_circle_fill, Colors.orange, () => _navegar(AdminActivarVendedorScreen()))),
          const SizedBox(width: 8),
          Expanded(child: _botonAccion('GENERAR BATCH', Icons.send, Colors.yellow, () => _navegar(AdminGenerarBatchScreen()))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _botonAccion('IMPORTAR VENTAS', Icons.upload_file, Colors.yellow, () => _navegar(AdminImportarDbScreen()))),
          const SizedBox(width: 8),
          Expanded(child: _botonAccion('MANTENIMIENTO', Icons.build, Colors.blue, () => _navegar(MantenimientoMenuScreen()))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _botonAccion('BACKUP SISTEMA', Icons.cloud_upload, Colors.green, () => _navegar(AdminBackupScreen()))),
          const SizedBox(width: 8),
          Expanded(child: _botonAccion('CUENTAS X COBRAR', Icons.monetization_on, Colors.orange, () => _navegar(CxcScreen()))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _botonAccion('RENTABILIDAD', Icons.trending_up, Colors.green, () => _navegar(RentabilidadScreen()))),
          const SizedBox(width: 8),
          Expanded(child: _botonAccion('REGISTRAR GASTO', Icons.shopping_cart, Colors.red, () => _navegar(CompraScreen()))),
        ]),
        const SizedBox(height: 20),
        const Text('DETALLE POR PUNTO DE VENTA', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        ..._resumenPorPv.map((r) { final cerrado = r['cerrado'] as bool; return Card(color: const Color(0xFF1A1A1A), margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(leading: CircleAvatar(backgroundColor: cerrado ? Colors.green : Colors.grey, child: Icon(cerrado ? Icons.check : Icons.schedule, color: Colors.black, size: 18)), title: Text('${r['pv_codigo']} - ${r['pv_nombre']}', style: const TextStyle(color: Colors.white, fontSize: 12)), subtitle: Text(cerrado ? 'CIERRE REGISTRADO' : 'SIN CIERRE', style: TextStyle(color: cerrado ? Colors.green : Colors.orange, fontSize: 10)), trailing: Text('S/ ${(r['ventas'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)))); }).toList(),
      ])),
    );
  }

  Widget _tarjeta(String t, double m, Color c) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 4), Text('S/ ${m.toStringAsFixed(2)}', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16))]));
  Widget _tarjetaInt(String t, int v, Color c) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 4), Text('$v', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16))]));
  Widget _botonAccion(String txt, IconData i, Color c, VoidCallback a) => ElevatedButton(onPressed: a, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: c, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: c, width: 1))), child: Column(children: [Icon(i, size: 28, color: c), const SizedBox(height: 6), Text(txt, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: c))]));
}