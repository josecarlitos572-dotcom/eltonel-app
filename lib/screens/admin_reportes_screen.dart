import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class AdminReportesScreen extends StatefulWidget {
  @override
  _AdminReportesScreenState createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  bool _cargando = true;
  String _periodo = 'HOY';

  double _totalVentas = 0.0;
  double _totalGastos = 0.0;
  double _utilidad = 0.0;
  int _totalVentasCant = 0;
  int _totalQuiebres = 0;
  int _totalCierres = 0;

  List<Map<String, dynamic>> _productosMasVendidos = [];
  List<Map<String, dynamic>> _quiebresPorProducto = [];
  List<Map<String, dynamic>> _resumenPorPv = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  String get _desde {
    final hoy = DateTime.now();
    if (_periodo == 'HOY') {
      return hoy.toIso8601String().split('T')[0];
    } else if (_periodo == 'SEMANA') {
      return hoy.subtract(Duration(days: 7)).toIso8601String().split('T')[0];
    } else if (_periodo == 'MES') {
      return hoy.subtract(Duration(days: 30)).toIso8601String().split('T')[0];
    }
    return hoy.subtract(Duration(days: 30)).toIso8601String().split('T')[0];
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final db2 = await db.database;

    final desde = _desde;
    final hoy = DateTime.now().toIso8601String().split('T')[0];

    // Ventas del período
    final ventas = await db2.rawQuery(
      'SELECT * FROM ventas WHERE fecha >= ? AND fecha <= ?',
      ['${desde}T00:00:00', '${hoy}T23:59:59'],
    );
    double sumaVentas = 0.0;
    for (var v in ventas) {
      sumaVentas += (v['monto_total'] as num?)?.toDouble() ?? 0.0;
    }

    // Gastos del período
    final gastos = await db2.rawQuery(
      'SELECT * FROM gastos_internos WHERE fecha >= ? AND fecha <= ?',
      ['${desde}T00:00:00', '${hoy}T23:59:59'],
    );
    double sumaGastos = 0.0;
    for (var g in gastos) {
      sumaGastos += (g['monto'] as num?)?.toDouble() ?? 0.0;
    }

    // Productos más vendidos
    final topProductos = await db2.rawQuery('''
      SELECT dv.producto_id, p.codigo, p.nombre,
             SUM(dv.cantidad) as total_cantidad,
             SUM(dv.subtotal) as total_monto
      FROM detalle_venta dv
      LEFT JOIN productos p ON dv.producto_id = p.id
      LEFT JOIN ventas v ON dv.venta_id = v.id
      WHERE v.fecha >= ? AND v.fecha <= ?
      GROUP BY dv.producto_id
      ORDER BY total_cantidad DESC
      LIMIT 10
    ''', ['${desde}T00:00:00', '${hoy}T23:59:59']);

    // Quiebres por producto
    final quiebres = await db2.rawQuery('''
      SELECT q.producto_id, p.codigo, p.nombre,
             COUNT(*) as total_quiebres,
             SUM(q.cantidad_pedida) as total_cantidad
      FROM quiebres q
      LEFT JOIN productos p ON q.producto_id = p.id
      WHERE q.fecha >= ? AND q.fecha <= ?
      GROUP BY q.producto_id
      ORDER BY total_quiebres DESC
      LIMIT 10
    ''', [desde, hoy]);

    // Cierres del período
    final cierres = await db2.rawQuery(
      'SELECT * FROM cierres_caja WHERE fecha >= ? AND fecha <= ?',
      [desde, hoy],
    );

    // Resumen por PV
    final puntos = await db.getPuntosVenta();
    final List<Map<String, dynamic>> resumenPv = [];
    for (var pv in puntos) {
      final pvId = pv['id'] as int;
      final ventasPv = await db2.rawQuery(
        'SELECT SUM(monto_total) as total, COUNT(*) as cant FROM ventas WHERE punto_venta_id = ? AND fecha >= ? AND fecha <= ?',
        [pvId, '${desde}T00:00:00', '${hoy}T23:59:59'],
      );
      final quiebresPv = await db2.rawQuery(
        'SELECT COUNT(*) as total FROM quiebres WHERE punto_venta_id = ? AND fecha >= ? AND fecha <= ?',
        [pvId, desde, hoy],
      );
      resumenPv.add({
        'codigo': pv['codigo'],
        'nombre': pv['nombre'],
        'ventas': (ventasPv.first['total'] as num?)?.toDouble() ?? 0.0,
        'cant_ventas': (ventasPv.first['cant'] as num?)?.toInt() ?? 0,
        'quiebres': (quiebresPv.first['total'] as num?)?.toInt() ?? 0,
      });
    }

    if (mounted) {
      setState(() {
        _totalVentas = sumaVentas;
        _totalGastos = sumaGastos;
        _utilidad = sumaVentas - sumaGastos;
        _totalVentasCant = ventas.length;
        _totalQuiebres = quiebres.fold(
            0, (s, q) => s + ((q['total_quiebres'] as num?)?.toInt() ?? 0));
        _totalCierres = cierres.length;
        _productosMasVendidos = topProductos;
        _quiebresPorProducto = quiebres;
        _resumenPorPv = resumenPv;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('REPORTES'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('REPORTES CONSOLIDADOS'),
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
            // Filtro de período
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chipPeriodo('HOY'),
                _chipPeriodo('SEMANA'),
                _chipPeriodo('MES'),
              ],
            ),
            SizedBox(height: 15),

            Text('RESUMEN DEL PERÍODO',
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
                    child: _tarjeta('UTILIDAD', _utilidad,
                        _utilidad >= 0 ? Colors.yellow : Colors.red)),
                SizedBox(width: 8),
                Expanded(
                    child: _tarjetaInt('TICKETS', _totalVentasCant, Colors.blue)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _tarjetaInt('QUIEBRES', _totalQuiebres, Colors.orange)),
                SizedBox(width: 8),
                Expanded(
                    child: _tarjetaInt('CIERRES', _totalCierres, Colors.purple)),
              ],
            ),

            SizedBox(height: 20),
            Text('RESUMEN POR PUNTO DE VENTA',
                style: TextStyle(
                    color: Colors.yellow,
                    fontFamily: 'CourierNew',
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            SizedBox(height: 10),
            ..._resumenPorPv.map((r) {
              return Card(
                color: Color(0xFF1A1A1A),
                margin: EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.yellow,
                    child: Text(r['codigo'] ?? '?',
                        style: TextStyle(
                            color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(r['nombre'] ?? '',
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'CourierNew', fontSize: 11)),
                  subtitle: Text(
                      '${r['cant_ventas']} tickets · ${r['quiebres']} quiebres',
                      style: TextStyle(
                          color: Colors.white54, fontFamily: 'CourierNew', fontSize: 9)),
                  trailing: Text('S/ ${(r['ventas'] as double).toStringAsFixed(2)}',
                      style: TextStyle(
                          color: Colors.yellow,
                          fontFamily: 'CourierNew',
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              );
            }).toList(),

            if (_productosMasVendidos.isNotEmpty) ...[
              SizedBox(height: 20),
              Text('TOP 10 PRODUCTOS VENDIDOS',
                  style: TextStyle(
                      color: Colors.yellow,
                      fontFamily: 'CourierNew',
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              SizedBox(height: 10),
              ..._productosMasVendidos.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                return Card(
                  color: Color(0xFF1A1A1A),
                  margin: EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${p['codigo']} ${p['nombre']}',
                        style: TextStyle(
                            color: Colors.white, fontFamily: 'CourierNew', fontSize: 11)),
                    trailing: Text('${p['total_cantidad']} uds',
                        style: TextStyle(
                            color: Colors.yellow,
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                );
              }).toList(),
            ],

            if (_quiebresPorProducto.isNotEmpty) ...[
              SizedBox(height: 20),
              Text('QUIEBRES POR PRODUCTO',
                  style: TextStyle(
                      color: Colors.orange,
                      fontFamily: 'CourierNew',
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              SizedBox(height: 10),
              ..._quiebresPorProducto.map((q) {
                return Card(
                  color: Color(0xFF1A1A1A),
                  margin: EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.warning, color: Colors.orange, size: 20),
                    title: Text('${q['codigo']} ${q['nombre']}',
                        style: TextStyle(
                            color: Colors.white, fontFamily: 'CourierNew', fontSize: 11)),
                    trailing: Text('${q['total_quiebres']} veces',
                        style: TextStyle(
                            color: Colors.orange,
                            fontFamily: 'CourierNew',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipPeriodo(String valor) {
    final activo = _periodo == valor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(valor, style: TextStyle(fontFamily: 'CourierNew', fontSize: 11)),
        selected: activo,
        onSelected: (v) {
          setState(() => _periodo = valor);
          _cargar();
        },
        selectedColor: Colors.yellow,
        backgroundColor: Colors.grey[900],
        labelStyle: TextStyle(color: activo ? Colors.black : Colors.white),
      ),
    );
  }

  Widget _tarjeta(String titulo, double monto, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
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
                  color: Colors.white70, fontFamily: 'CourierNew', fontSize: 9)),
          SizedBox(height: 4),
          Text('S/ ${monto.toStringAsFixed(2)}',
              style: TextStyle(
                  color: color,
                  fontFamily: 'CourierNew',
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _tarjetaInt(String titulo, int valor, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
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
                  color: Colors.white70, fontFamily: 'CourierNew', fontSize: 9)),
          SizedBox(height: 4),
          Text('$valor',
              style: TextStyle(
                  color: color,
                  fontFamily: 'CourierNew',
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}