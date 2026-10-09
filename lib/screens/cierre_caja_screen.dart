import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class CierreCajaScreen extends StatefulWidget {
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends State<CierreCajaScreen> {
  final TextEditingController _efectivoCtrl = TextEditingController();
  final TextEditingController _digitalCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();

  List<Map<String, dynamic>> _productosStock = [];
  double _saldoInicial = 0.0;
  double _totalVentas = 0.0;
  double _totalGastos = 0.0;
  bool _cargando = true;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
    });
  }

  int get _pvId {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.currentUser?['punto_venta_id'] ?? 2;
  }

  Future<void> _cargarDatos() async {
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final pvId = _pvId;

    // Cargar apertura de caja (saldo inicial)
    final aperturas = await db.consultar('aperturas_caja',
        where: 'fecha = ? AND punto_venta_id = ?',
        whereArgs: [_hoy, pvId]);
    if (aperturas.isNotEmpty) {
      _saldoInicial = (aperturas.first['saldo_inicial'] as num?)?.toDouble() ?? 0.0;
    }

    // Cargar ventas del día
    final ventas = await db.consultar('ventas',
        where: 'fecha LIKE ? AND punto_venta_id = ?',
        whereArgs: ['$_hoy%', pvId]);
    _totalVentas = ventas.fold(0.0,
        (sum, v) => sum + ((v['monto_total'] as num?)?.toDouble() ?? 0.0));

    // Cargar gastos del día
    final gastos = await db.consultar('gastos_internos',
        where: 'fecha LIKE ?', whereArgs: ['$_hoy%']);
    _totalGastos = gastos.fold(0.0,
        (sum, g) => sum + ((g['monto'] as num?)?.toDouble() ?? 0.0));

    // Cargar stock actual del día
    final stockHoy = await db.consultar('inventario',
        where: 'punto_venta_id = ? AND fecha = ?',
        whereArgs: [pvId, _hoy]);

    // Enriquecer con nombre de producto
    final productos = db.products;
    final List<Map<String, dynamic>> stockConNombre = [];
    for (var s in stockHoy) {
      final prod = productos.firstWhere(
        (p) => p['id'] == s['producto_id'],
        orElse: () => {'nombre': 'Desconocido', 'codigo': '??'},
      );
      stockConNombre.add({
        ...s,
        'nombre': prod['nombre'],
        'codigo': prod['codigo'],
      });
    }

    if (mounted) {
      setState(() {
        _productosStock = stockConNombre;
        _cargando = false;
      });
    }
  }

  double get _saldoTeorico => _saldoInicial + _totalVentas - _totalGastos;

  double get _totalRetorno {
    return _productosStock.fold(0, (sum, p) {
      return sum + ((p['stock'] as num?)?.toInt() ?? 0);
    });
  }

  Future<void> _confirmarCierre() async {
    final efectivo = double.tryParse(_efectivoCtrl.text) ?? 0.0;
    final digital = double.tryParse(_digitalCtrl.text) ?? 0.0;

    if (_efectivoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingrese el efectivo contado'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('¿CONFIRMAR CIERRE?',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 15)),
        content: Text(
          'Al cerrar:\n\n'
          '- Se cierra tu asignación de hoy\n'
          '- El stock retorna a BASE (${_totalRetorno.toInt()} unidades)\n'
          '- El stock queda en 0 para mañana\n\n'
          '¿Continuar?',
          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('NO', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('SÍ, CERRAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final pvId = _pvId;
    final usuarioId = auth.currentUser?['id'];

    try {
      // 1. Registrar cierre de caja
      await db.insertar('cierres_caja', {
        'fecha': _hoy,
        'punto_venta_id': pvId,
        'personal_id': usuarioId,
        'saldo_inicial': _saldoInicial,
        'total_ventas': _totalVentas,
        'total_gastos_manuales': _totalGastos,
        'saldo_teorico': _saldoTeorico,
        'saldo_real_contado': efectivo + digital,
        'diferencia': (efectivo + digital) - _saldoTeorico,
        'observaciones': _observacionesCtrl.text,
      });

      // 2. Cerrar asignación activa del día
      final asignaciones = await db.consultar('asignaciones_diarias',
          where: 'usuario_id = ? AND fecha = ? AND estado = ?',
          whereArgs: [usuarioId, _hoy, 'ACTIVO']);
      for (var a in asignaciones) {
        await db.actualizar('asignaciones_diarias', {
          'id': a['id'],
          'estado': 'CERRADO',
          'hora_fin': DateTime.now().toIso8601String(),
        });
      }

      // 3. Resetear stock a cero
      for (var p in _productosStock) {
        await db.actualizar('inventario', {
          'id': p['id'],
          'stock': 0,
        });
      }

      // 4. Auditoría
      await db.insertar('auditoria_cambios', {
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': usuarioId,
        'usuario_nombre': auth.currentUser?['nombres'] ?? '',
        'tabla_afectada': 'cierres_caja',
        'accion': 'CIERRE_JORNADA',
        'registro_id': pvId,
        'datos_anteriores': null,
        'datos_nuevos': 'Stock reseteado a 0. Retorno: ${_totalRetorno.toInt()} uds',
      });

      if (mounted) {
        // Logout tras cierre
        auth.logout();
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('CIERRE DE CAJA'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('CIERRE DE CAJA'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filaDato('Fecha:', _hoy),
            _filaDato('Saldo inicial:', 'S/ ${_saldoInicial.toStringAsFixed(2)}'),
            _filaDato('Total ventas:', 'S/ ${_totalVentas.toStringAsFixed(2)}'),
            _filaDato('Total gastos:', 'S/ ${_totalGastos.toStringAsFixed(2)}'),
            Divider(color: Colors.yellow),
            _filaDato('SALDO TEÓRICO:', 'S/ ${_saldoTeorico.toStringAsFixed(2)}', negrita: true),

            SizedBox(height: 20),
            Text('CONTEO FÍSICO',
                style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextField(
              controller: _efectivoCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Efectivo contado',
                labelStyle: TextStyle(color: Colors.yellow),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _digitalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Pago digital (Yape/Plin/Transf)',
                labelStyle: TextStyle(color: Colors.yellow),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _observacionesCtrl,
              decoration: InputDecoration(
                labelText: 'Observaciones (opcional)',
                labelStyle: TextStyle(color: Colors.yellow),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),

            SizedBox(height: 20),
            Text('RETORNO A BASE',
                style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text('${_productosStock.length} productos · ${_totalRetorno.toInt()} unidades sin vender',
                style: TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 12)),
            SizedBox(height: 10),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border.all(color: Colors.yellow54),
              ),
              child: _productosStock.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('Sin stock registrado hoy',
                          style: TextStyle(color: Colors.white38, fontFamily: 'CourierNew', fontSize: 11)),
                    )
                  : ListView.builder(
                      itemCount: _productosStock.length,
                      itemBuilder: (ctx, i) {
                        final p = _productosStock[i];
                        return ListTile(
                          dense: true,
                          title: Text('${p['codigo']} ${p['nombre']}',
                              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                          trailing: Text('${p['stock']}',
                              style: TextStyle(color: Colors.orange, fontFamily: 'CourierNew', fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmarCierre,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 55),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('CERRAR JORNADA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, {bool negrita = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'CourierNew',
                  fontSize: negrita ? 14 : 12,
                  fontWeight: negrita ? FontWeight.bold : FontWeight.normal)),
          Text(valor,
              style: TextStyle(
                  color: negrita ? Colors.yellow : Colors.white,
                  fontFamily: 'CourierNew',
                  fontSize: negrita ? 14 : 12,
                  fontWeight: negrita ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}