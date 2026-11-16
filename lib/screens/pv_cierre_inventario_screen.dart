import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class PvCierreInventarioScreen extends StatefulWidget {
  @override
  _PvCierreInventarioScreenState createState() => _PvCierreInventarioScreenState();
}

class _PvCierreInventarioScreenState extends State<PvCierreInventarioScreen> {
  List<Map<String, dynamic>> _productosConteo = [];
  bool _cargando = true;
  final Map<int, TextEditingController> _sobrantesCtrl = {};

  String get _hoy => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarConteo());
  }

  @override
  void dispose() {
    for (var ctrl in _sobrantesCtrl.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarConteo() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final pvId = auth.currentUser?['punto_venta_id_actual'] as int? ?? 0;
    final db2 = await db.database;

    final stockActual = await db2.query('inventario',
        where: 'punto_venta_id = ? AND fecha = ?',
        whereArgs: [pvId, _hoy]);

    final ventas = await db2.rawQuery('''
      SELECT dv.producto_id, SUM(dv.cantidad) as total_vendido
      FROM detalle_venta dv
      INNER JOIN ventas v ON dv.venta_id = v.id
      WHERE v.punto_venta_id = ? AND v.fecha LIKE ?
      GROUP BY dv.producto_id
    ''', [pvId, '$_hoy%']);

    final enviados = await db2.rawQuery('''
      SELECT producto_id, SUM(cantidad) as total_enviado
      FROM transferencias
      WHERE origen_id = ? AND fecha LIKE ?
      GROUP BY producto_id
    ''', [pvId, '$_hoy%']);

    final recibidos = await db2.rawQuery('''
      SELECT producto_id, SUM(cantidad) as total_recibido
      FROM transferencias
      WHERE destino_id = ? AND fecha LIKE ?
      GROUP BY producto_id
    ''', [pvId, '$_hoy%']);

    Map<int, int> mapStock = {for (var s in stockActual) s['producto_id'] as int: (s['stock'] as num?)?.toInt() ?? 0};
    Map<int, int> mapVentas = {for (var v in ventas) v['producto_id'] as int: (v['total_vendido'] as num?)?.toInt() ?? 0};
    Map<int, int> mapEnv = {for (var e in enviados) e['producto_id'] as int: (e['total_enviado'] as num?)?.toInt() ?? 0};
    Map<int, int> mapRec = {for (var r in recibidos) r['producto_id'] as int: (r['total_recibido'] as num?)?.toInt() ?? 0};

    final productos = await db.getProductos();
    List<Map<String, dynamic>> conteo = [];

    for (var p in productos) {
      final id = p['id'] as int;
      int stockBD = mapStock[id] ?? 0;
      int vendidos = mapVentas[id] ?? 0;
      int env = mapEnv[id] ?? 0;
      int rec = mapRec[id] ?? 0;

      if (stockBD != 0 || vendidos != 0 || env != 0 || rec != 0) {
        conteo.add({
          'id': id,
          'codigo': p['codigo'],
          'nombre': p['nombre'],
          'stock_bd': stockBD,
          'vendidos': vendidos,
          'enviados': env,
          'recibidos': rec,
        });
        _sobrantesCtrl[id] = TextEditingController(text: stockBD.toString());
      }
    }

    if (mounted) {
      setState(() {
        _productosConteo = conteo;
        _cargando = false;
      });
    }
  }

  Future<void> _procesarCierre() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final pvId = auth.currentUser?['punto_venta_id_actual'] as int? ?? 0;
    final db2 = await db.database;

    setState(() => _cargando = true);

    try {
      await db2.transaction((txn) async {
        for (var item in _productosConteo) {
          final id = item['id'] as int;
          final stockBD = item['stock_bd'] as int;
          final sobranteReal = int.tryParse(_sobrantesCtrl[id]?.text ?? '') ?? 0;
          final merma = stockBD - sobranteReal;

          if (merma > 0) {
            await txn.insert('quiebres', {
              'fecha': _hoy,
              'hora': DateFormat('HH:mm').format(DateTime.now()),
              'punto_venta_id': pvId,
              'producto_id': id,
              'tipo': 'MERMA_CIERRE',
              'cantidad_pedida': merma,
              'usuario_id': auth.currentUser?['id'],
              'observaciones': 'Físico: $sobranteReal vs Sistema: $stockBD',
            });
          }

          await txn.rawUpdate(
            'UPDATE inventario SET stock = 0 WHERE producto_id = ? AND punto_venta_id = ? AND fecha = ?',
            [id, pvId, _hoy],
          );
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mermas registradas y stock a cero.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('CONTEÍDO FÍSICO (CIERRE)')),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
          : Column(
              children: [
                Expanded(
                  child: _productosConteo.isEmpty
                      ? Center(child: Text('Sin movimientos hoy', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _productosConteo.length,
                          itemBuilder: (ctx, i) {
                            final p = _productosConteo[i];
                            final id = p['id'] as int;
                            return Card(
                              color: Color(0xFF1E1E1E),
                              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${p['codigo']} - ${p['nombre']}',
                                            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12, fontWeight: FontWeight.bold)),
                                        Spacer(),
                                        Text('Sist: ${p['stock_bd']}',
                                            style: TextStyle(color: Color(0xFFFFC107), fontFamily: 'CourierNew', fontSize: 11)),
                                      ],
                                    ),
                                    Text('Vend: ${p['vendidos']} | Env: ${p['enviados']} | Rec: ${p['recibidos']}',
                                        style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 9)),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text('Físico: ', style: TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 11)),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 80,
                                          height: 35,
                                          child: TextField(
                                            controller: _sobrantesCtrl[id],
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.green, fontFamily: 'CourierNew', fontSize: 14, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.black,
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  color: Colors.grey[900],
                  child: ElevatedButton.icon(
                    onPressed: _procesarCierre,
                    icon: Icon(Icons.check_circle, color: Colors.black),
                    label: Text('REGISTRAR MERMA Y DESMEDRAR'),
                  ),
                ),
              ],
            ),
    );
  }
}