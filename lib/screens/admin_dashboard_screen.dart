import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _puntosVenta = [];
  List<Map<String, dynamic>> _resumenPorPv = [];
  List<Map<String, dynamic>> _cierreHoy = [];
  bool _cargando = true;
  double _totalVentas = 0.0;
  double _totalGastos = 0.0;
  int _totalQuiebres = 0;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);

    final puntos = await db.getPuntosVenta();
    final List<Map<String, dynamic>> resumen = [];
    double sumaVentas = 0.0;

    for (var pv in puntos) {
      final pvId = pv['id'] as int;
      final ventas = await db.consultar('ventas',
          where: 'fecha LIKE ? AND punto_venta_id = ?',
          whereArgs: ['$_hoy%', pvId]);
      final total = ventas.fold(
          0.0, (s, v) => s + ((v['monto_total'] as num?)?.toDouble() ?? 0.0));

      final cierre = await db.consultar('cierres_caja',
          where: 'fecha = ? AND punto_venta_id = ?',
          whereArgs: [_hoy, pvId]);

      final quiebres = await db.consultar('quiebres',
          where: 'fecha LIKE ? AND punto_venta_id = ?',
          whereArgs: ['$_hoy%', pvId]);

      sumaVentas += total;
      resumen.add({
        'pv_id': pvId,
        'pv_codigo': pv['codigo'],
        'pv_nombre': pv['nombre'],
        'ventas': total,
        'cerrado': cierre.isNotEmpty,
        'quiebres': quiebres.length,
      });
    }

    final gastos = await db.consultar('gastos_internos',
        where: 'fecha LIKE ?', whereArgs: ['$_hoy%']);
    final totalGastos = gastos.fold(
        0.0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0.0));

    final cierresHoy = await db.rawQuery('''
      SELECT c.*, pv.codigo as pv_codigo, pv.nombre as pv_nombre
      FROM cierres_caja c
      LEFT JOIN puntos_venta pv ON c.punto_venta_id = pv.id
      WHERE c.fecha = ?
      ORDER BY pv.id
    ''', [_hoy]);

    int totalQ = 0;
    for (var r in resumen) {
      totalQ += r['quiebres'] as int;
    }

    if (mounted) {
      setState(() {
        _puntosVenta = puntos;
        _resumenPorPv = resumen;
        _cierreHoy = cierresHoy;
        _totalVentas = sumaVentas;
        _totalGastos = totalGastos;
        _totalQuiebres = totalQ;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('DASHBOARD'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    final utilidad = _totalVentas - _totalGastos;

    return Scaffold(
      appBar: AppBar(
        title: Text('DASHBOARD DEL DÍA'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('RESUMEN GENERAL — $_hoy',
                style: TextStyle(
                    color: Colors.yellow,
                    fontFamily: 'CourierNew',
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _tarjeta('VENTAS', _totalVentas, Colors.green)),
                SizedBox(width: 8),
                Expanded(child: _tarjeta('GASTOS', _totalGastos, Colors.red)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _tarjeta('UTILIDAD', utilidad,
                        utilidad >= 0 ? Colors.yellow : Colors.red)),
                SizedBox(width: 8),
                Expanded(
                    child: _tarjetaInt('QUIEBRES', _totalQuiebres, Colors.orange)),
              ],
            ),

            SizedBox(height: 20),
            Text('DETALLE POR PUNTO DE VENTA',
                style: TextStyle(
                    color: Colors.yellow,
                    fontFamily: 'CourierNew',
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            SizedBox(height: 10),

            ..._resumenPorPv.map((r) {
              final cerrado = r['cerrado'] as bool;
              return Card(
                color: Color(0xFF1A1A1A),
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cerrado ? Colors.green : Colors.grey,
                    child: Icon(
                      cerrado ? Icons.check : Icons.schedule,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                  title: Text('${r['pv_codigo']} - ${r['pv_nombre']}',
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'CourierNew',
                          fontSize: 12)),
                  subtitle: Text(
                    cerrado ? 'CIERRE REGISTRADO' : 'SIN CIERRE',
                    style: TextStyle(
                        color: cerrado ? Colors.green : Colors.orange,
                        fontFamily: 'CourierNew',
                        fontSize: 10),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          'S/ ${(r['ventas'] as double).toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Colors.yellow,
                              fontFamily: 'CourierNew',
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text('${r['quiebres']} quiebres',
                          style: TextStyle(
                              color: Colors.white54,
                              fontFamily: 'CourierNew',
                              fontSize: 10)),
                    ],
                  ),
                ),
              );
            }).toList(),

            if (_cierreHoy.isNotEmpty) ...[
              SizedBox(height: 20),
              Text('CUADRE DE CAJA DEL DÍA',
                  style: TextStyle(
                      color: Colors.yellow,
                      fontFamily: 'CourierNew',
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              SizedBox(height: 10),
              ..._cierreHoy.map((c) {
                final diferencia =
                    (c['diferencia'] as num?)?.toDouble() ?? 0.0;
                final colorDif =
                    diferencia == 0 ? Colors.green : (diferencia > 0 ? Colors.orange : Colors.red);
                return Card(
                  color: Color(0xFF1A1A1A),
                  margin: EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    title: Text('${c['pv_codigo']} - ${c['pv_nombre']}',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CourierNew',
                            fontSize: 12)),
                    subtitle: Text(
                      'Teórico: S/ ${(c['saldo_teorico'] as num?)?.toStringAsFixed(2)} · Contado: S/ ${(c['saldo_real_contado'] as num?)?.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'CourierNew',
                          fontSize: 10),
                    ),
                    trailing: Text(
                      'S/ ${diferencia.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: colorDif,
                          fontFamily: 'CourierNew',
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(String titulo, double monto, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'CourierNew',
                  fontSize: 10)),
          SizedBox(height: 4),
          Text('S/ ${monto.toStringAsFixed(2)}',
              style: TextStyle(
                  color: color,
                  fontFamily: 'CourierNew',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _tarjetaInt(String titulo, int valor, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'CourierNew',
                  fontSize: 10)),
          SizedBox(height: 4),
          Text('$valor',
              style: TextStyle(
                  color: color,
                  fontFamily: 'CourierNew',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }
}