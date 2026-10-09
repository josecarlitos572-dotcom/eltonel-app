import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class QuiebresScreen extends StatefulWidget {
  @override
  _QuiebresScreenState createState() => _QuiebresScreenState();
}

class _QuiebresScreenState extends State<QuiebresScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _quiebresHoy = [];
  bool _cargando = true;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  int get _pvId {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.currentUser?['punto_venta_id'] ?? 2;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final productos = await db.getProductos();
    final quiebres = await db.consultar('quiebres',
        where: 'fecha LIKE ? AND punto_venta_id = ?',
        whereArgs: ['$_hoy%', _pvId],
        orderBy: 'id DESC');

    if (mounted) {
      setState(() {
        _productos = productos.where((p) => (p['activo'] ?? 1) == 1).toList();
        _quiebresHoy = quiebres;
        _cargando = false;
      });
    }
  }

  Future<void> _registrarQuiebre(Map<String, dynamic> producto) async {
    final cantidadCtrl = TextEditingController(text: '1');
    bool consultoBase = false;
    bool consultoOtros = false;
    bool recuperado = false;
    String tipo = 'PRIMARIO';

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: Text('QUIEBRE: ${producto['codigo']}',
                  style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 14)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto['nombre'] ?? '',
                        style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                    SizedBox(height: 12),
                    TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cantidad pedida',
                        labelStyle: TextStyle(color: Colors.yellow),
                        isDense: true,
                      ),
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                    SizedBox(height: 12),
                    CheckboxListTile(
                      value: consultoBase,
                      onChanged: (v) => setStateDialog(() => consultoBase = v ?? false),
                      title: Text('Consulté a BASE',
                          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                      activeColor: Colors.yellow,
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: consultoOtros,
                      onChanged: (v) => setStateDialog(() => consultoOtros = v ?? false),
                      title: Text('Consulté a otros PV',
                          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                      activeColor: Colors.yellow,
                      dense: true,
                    ),
                    CheckboxListTile(
                      value: recuperado,
                      onChanged: (v) => setStateDialog(() => recuperado = v ?? false),
                      title: Text('Se recuperó por traslado',
                          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                      activeColor: Colors.yellow,
                      dense: true,
                    ),
                    SizedBox(height: 8),
                    Text('Tipo de quiebre:',
                        style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 12)),
                    RadioListTile<String>(
                      value: 'PRIMARIO',
                      groupValue: tipo,
                      onChanged: (v) => setStateDialog(() => tipo = v ?? 'PRIMARIO'),
                      title: Text('PRIMARIO (había en algún lado)',
                          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 11)),
                      activeColor: Colors.yellow,
                      dense: true,
                    ),
                    RadioListTile<String>(
                      value: 'SECUNDARIO',
                      groupValue: tipo,
                      onChanged: (v) => setStateDialog(() => tipo = v ?? 'PRIMARIO'),
                      title: Text('SECUNDARIO (no había en ningún lado)',
                          style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 11)),
                      activeColor: Colors.orange,
                      dense: true,
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
            );
          },
        );
      },
    );

    if (guardar == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final cantidad = int.tryParse(cantidadCtrl.text) ?? 1;

      try {
        await db.insertar('quiebres', {
          'fecha': _hoy,
          'hora': DateTime.now().toIso8601String().substring(11, 16),
          'punto_venta_id': _pvId,
          'producto_id': producto['id'],
          'tipo': tipo,
          'cantidad_pedida': cantidad,
          'consultado_base': consultoBase ? 1 : 0,
          'consultado_otros_puntos': consultoOtros ? 1 : 0,
          'recuperado_por_traslado': recuperado ? 1 : 0,
          'venta_perdida_estimada': recuperado ? 0.0 : 2.0 * cantidad,
          'usuario_id': auth.currentUser?['id'],
          'observaciones': '',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quiebre registrado'), backgroundColor: Colors.green),
        );

        _cargarTodo();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('QUIEBRES'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('QUIEBRES DEL DÍA (${_quiebresHoy.length})'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarTodo),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (_quiebresHoy.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              color: Color(0xFF1A1A1A),
              child: ListView.builder(
                itemCount: _quiebresHoy.length,
                itemBuilder: (ctx, i) {
                  final q = _quiebresHoy[i];
                  final prod = _productos.firstWhere(
                    (p) => p['id'] == q['producto_id'],
                    orElse: () => {'nombre': '?', 'codigo': '?'},
                  );
                  final esPrimario = q['tipo'] == 'PRIMARIO';
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      esPrimario ? Icons.warning : Icons.error,
                      color: esPrimario ? Colors.orange : Colors.red,
                    ),
                    title: Text('${prod['codigo']} ${prod['nombre']}',
                        style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                    subtitle: Text('${q['tipo']} · ${q['cantidad_pedida']} uds',
                        style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 10)),
                    trailing: Text('${q['hora']}',
                        style: TextStyle(color: Colors.white38, fontFamily: 'CourierNew', fontSize: 10)),
                  );
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _productos.length,
              itemBuilder: (ctx, i) {
                final p = _productos[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.yellow,
                    child: Text(p['codigo'] ?? '?',
                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p['nombre'] ?? '',
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13)),
                  trailing: IconButton(
                    icon: Icon(Icons.warning_amber, color: Colors.orange),
                    onPressed: () => _registrarQuiebre(p),
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