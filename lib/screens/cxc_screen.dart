import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class CxcScreen extends StatefulWidget {
  @override
  _CxcScreenState createState() => _CxcScreenState();
}

class _CxcScreenState extends State<CxcScreen> {
  List<Map<String, dynamic>> _cuentas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);

    final cuentas = await db.consultarCuentasPendientes();

    if (mounted) {
      setState(() {
        _cuentas = cuentas;
        _cargando = false;
      });
    }
  }

  int _diasAtraso(String? fechaVencimiento) {
    if (fechaVencimiento == null) return 0;
    try {
      final venc = DateTime.parse(fechaVencimiento);
      final hoy = DateTime.now();
      return hoy.difference(venc).inDays;
    } catch (e) {
      return 0;
    }
  }

  Color _colorAlerta(double saldo, int dias) {
    if (saldo > 100 && dias > 7) return Colors.red;
    if (saldo > 50 && dias > 5) return Colors.deepOrange;
    if (saldo > 20 && dias > 3) return Colors.orange;
    return Colors.yellow;
  }

  Future<void> _registrarAbono(Map<String, dynamic> cuenta) async {
    final saldoActual = (cuenta['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
    final montoCtrl = TextEditingController(text: saldoActual.toStringAsFixed(2));
    final obsCtrl = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('REGISTRAR ABONO',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cliente: ${cuenta['cliente_nombre'] ?? ''}',
                  style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
              SizedBox(height: 6),
              Text('Saldo pendiente: S/ ${saldoActual.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: Colors.orange,
                      fontFamily: 'CourierNew',
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monto a abonar',
                  labelStyle: TextStyle(color: Colors.yellow),
                  isDense: true,
                ),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                decoration: InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  labelStyle: TextStyle(color: Colors.yellow),
                  isDense: true,
                ),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('REGISTRAR', style: TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
    );

    if (resultado != true) return;

    final monto = double.tryParse(montoCtrl.text) ?? 0.0;
    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
      );
      return;
    }

    if (monto > saldoActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('El abono excede el saldo pendiente'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final nuevoSaldo = saldoActual - monto;
      final nuevoEstado = nuevoSaldo <= 0 ? 'PAGADO' : 'PENDIENTE';

      await db.actualizar('cuentas_por_cobrar', {
        'id': cuenta['id'],
        'monto_pagado':
            ((cuenta['monto_pagado'] as num?)?.toDouble() ?? 0.0) + monto,
        'saldo_pendiente': nuevoSaldo,
        'estado': nuevoEstado,
      });

      await db.insertar('cobros', {
        'cuenta_id': cuenta['id'],
        'fecha_cobro': DateTime.now().toIso8601String(),
        'monto_cobrado': monto,
        'tipo_pago': 'EFECTIVO',
        'usuario_id': auth.currentUser?['id'],
        'observaciones': obsCtrl.text.trim(),
      });

      await db.insertar('auditoria_cambios', {
        'fecha': DateTime.now().toIso8601String(),
        'usuario_id': auth.currentUser?['id'],
        'usuario_nombre': auth.currentUser?['nombres'] ?? '',
        'tabla_afectada': 'cuentas_por_cobrar',
        'accion': 'ABONO_REGISTRADO',
        'registro_id': cuenta['id'],
        'datos_anteriores': 'Saldo: $saldoActual',
        'datos_nuevos': 'Saldo: $nuevoSaldo',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abono registrado: S/ ${monto.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );

      _cargar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            title: Text('CUENTAS POR COBRAR'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    double totalPorCobrar = 0.0;
    double totalVencido = 0.0;
    for (var c in _cuentas) {
      final saldo = (c['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
      totalPorCobrar += saldo;
      if (_diasAtraso(c['fecha_vencimiento'] as String?) > 0) {
        totalVencido += saldo;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('CUENTAS X COBRAR (${_cuentas.length})'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            color: Color(0xFF1A1A1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('POR COBRAR',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'CourierNew',
                            fontSize: 10)),
                    Text('S/ ${totalPorCobrar.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.yellow,
                            fontFamily: 'CourierNew',
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('VENCIDO',
                        style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'CourierNew',
                            fontSize: 10)),
                    Text('S/ ${totalVencido.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.red,
                            fontFamily: 'CourierNew',
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _cuentas.isEmpty
                ? Center(
                    child: Text('Sin cuentas pendientes',
                        style: TextStyle(
                            color: Colors.white54, fontFamily: 'CourierNew')),
                  )
                : ListView.builder(
                    itemCount: _cuentas.length,
                    itemBuilder: (ctx, i) {
                      final c = _cuentas[i];
                      final saldo =
                          (c['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
                      final dias = _diasAtraso(c['fecha_vencimiento'] as String?);
                      final color = _colorAlerta(saldo, dias);

                      return Card(
                        color: Color(0xFF1A1A1A),
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color,
                            child: Icon(
                              dias > 0 ? Icons.warning : Icons.schedule,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            c['cliente_nombre'] ?? 'Sin nombre',
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'CourierNew',
                                fontSize: 13),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saldo: S/ ${saldo.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: color,
                                      fontFamily: 'CourierNew',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                dias > 0
                                    ? 'VENCIDO hace $dias días'
                                    : 'Vence: ${c['fecha_vencimiento'] ?? '-'}',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontFamily: 'CourierNew',
                                    fontSize: 10),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.payments, color: Colors.yellow, size: 26),
                            onPressed: () => _registrarAbono(c),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}