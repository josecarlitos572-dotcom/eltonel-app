import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class AdminGenerarBatchScreen extends StatefulWidget {
  @override
  _AdminGenerarBatchScreenState createState() => _AdminGenerarBatchScreenState();
}

class _AdminGenerarBatchScreenState extends State<AdminGenerarBatchScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _puntos = [];
  Map<int, TextEditingController> _cantidades = {};
  bool _cargando = false;
  String _busqueda = '';
  String _tipo = 'ABASTO';
  int? _pvDestinoId;

  String get _hoy => DateTime.now().toIso8601String().split('T')[0];

  // REM: FASE 1 - Números de WhatsApp. Cambia estos por los reales de tus vendedores.
  final Map<String, String> _whatsappMap = {
    'SR1': '51988888888', 
    'VR1': '51977777777', 
    'VR2': '51966666666', 
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  @override
  void dispose() {
    for (var c in _cantidades.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final productos = await db.getProductos();
    final puntos = await db.getPuntosVenta();

    if (mounted) {
      setState(() {
        _productos = productos.where((p) => (p['activo'] ?? 1) == 1).toList();
        _puntos = puntos.where((p) => p['id'] != 1).toList();
        if (_puntos.isNotEmpty) {
          _pvDestinoId = _puntos.first['id'] as int;
        }
        for (var p in _productos) {
          _cantidades[p['id'] as int] = TextEditingController();
        }
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busqueda.isEmpty) return _productos;
    final q = _busqueda.toLowerCase();
    return _productos.where((p) {
      final cod = (p['codigo'] ?? '').toString().toLowerCase();
      final nom = (p['nombre'] ?? '').toString().toLowerCase();
      return cod.contains(q) || nom.contains(q);
    }).toList();
  }

  int get _totalUnidades {
    int total = 0;
    _cantidades.forEach((_, ctrl) {
      final val = int.tryParse(ctrl.text) ?? 0;
      total += val;
    });
    return total;
  }

  int get _totalProductos {
    return _cantidades.values.where((ctrl) => (int.tryParse(ctrl.text) ?? 0) > 0).length;
  }

  Future<void> _generarYEnviarBatch() async {
    List<Map<String, dynamic>> carrito = [];
    for (var p in _productos) {
      final id = p['id'] as int;
      final cant = int.tryParse(_cantidades[id]?.text ?? '') ?? 0;
      if (cant > 0) {
        carrito.add({'producto_id': id, 'cantidad': cant});
      }
    }

    if (carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asigna cantidad a por lo menos un producto'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_pvDestinoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un punto de venta destino'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final pvDestino = _puntos.firstWhere((p) => p['id'] == _pvDestinoId);
      final pvCodigo = pvDestino['codigo'] as String;
      final pvNombre = pvDestino['nombre'] as String;

      // REM: FASE 1 - Usamos el método oficial del helper (garantiza version: 2 y hash correcto)
      final jsonStr = await db.generarBatchJson(
        tipo: _tipo,
        origenCodigo: 'BASE',
        destinoCodigo: pvCodigo,
        dniEmisor: auth.currentUser?['dni'] ?? '09878372',
        items: carrito,
      );

      // REM: FASE 1 - Mensaje legible para WhatsApp
      final resumenProductos = carrito.map((item) {
        final prod = _productos.firstWhere((p) => p['id'] == item['producto_id']);
        return '• ${item['cantidad']} x ${prod['nombre']}';
      }).join('\n');

      final mensajeWsp = '📦 *BATCH DE $_tipo - EL TONEL*\n'
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
          '📍 Origen: BASE\n'
          '📍 Destino: $pvCodigo - $pvNombre\n'
          '📅 Fecha: $_hoy\n'
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
          '📋 *PRODUCTOS:*\n$resumenProductos\n'
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
          '📦 *Total: $_totalProductos productos | $_totalUnidades unidades*\n'
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
          '✅ *Para recibir, abre la app y presiona "Recibir Entrada"*';

      // REM: FASE 1 - Abrir WhatsApp automáticamente
      final numeroWsp = _whatsappMap[pvCodigo] ?? '';
      final uri = Uri.parse('https://wa.me/$numeroWsp?text=${Uri.encodeComponent(mensajeWsp)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Batch generado y WhatsApp abierto para $pvNombre'),
              backgroundColor: Colors.green,
            ),
          );
          for (var ctrl in _cantidades.values) {
            ctrl.clear();
          }
          setState(() {});
        }
      } else {
        await Clipboard.setData(ClipboardData(text: jsonStr));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ WhatsApp no disponible. JSON copiado al portapapeles.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
      );
    }

    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CARGA MASIVA (STOCK)'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('TIPO: ', style: TextStyle(color: Color(0xFFFFC107), fontFamily: 'CourierNew', fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tipo,
                        dropdownColor: Colors.black,
                        style: const TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          labelStyle: TextStyle(color: Color(0xFFFFC107)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ABASTO', child: Text('ABASTO', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'REABASTO', child: Text('REABASTO', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (v) => setState(() => _tipo = v ?? 'ABASTO'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _pvDestinoId,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Punto de venta destino',
                    labelStyle: TextStyle(color: Color(0xFFFFC107)),
                    isDense: true,
                  ),
                  items: _puntos.map<DropdownMenuItem<int>>((p) {
                    return DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text('${p['codigo']} - ${p['nombre']}', style: const TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _pvDestinoId = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFFC107)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtrados.length,
              itemBuilder: (ctx, i) {
                final p = filtrados[i];
                final id = p['id'] as int;
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white12))
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFC107),
                      child: Text(p['codigo'] ?? '?', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12)),
                    trailing: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _cantidades[id],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.black,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107), width: 2)),
                        ),
                        style: const TextStyle(color: Color(0xFFFFC107), fontFamily: 'CourierNew', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey[900],
            child: Column(
              children: [
                Text(
                  '$_totalProductos productos · $_totalUnidades unidades asignadas',
                  style: const TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 12),
                ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: _generarYEnviarBatch,
                  icon: const Icon(Icons.send, color: Colors.black),
                  label: const Text('GENERAR Y ENVIAR POR WSP'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontFamily: 'CourierNew', fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}