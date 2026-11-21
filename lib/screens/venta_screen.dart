import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'scanner_screen.dart';
import 'pv_importar_entrada_screen.dart';

class VentaScreen extends StatefulWidget {
  const VentaScreen({Key? key}) : super(key: key);
  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  static const Color _amber = Color(0xFFFFC107);
  static const Color _bg = Color(0xFF121212);
  static const Color _surface = Color(0xFF1E1E1E);
  static const Color _card = Color(0xFF242424);
  static const Color _green = Color(0xFF43A047);
  static const Color _yape = Color(0xFF742284);
  static const Color _plin = Color(0xFF00A9E0);
  static const Color _red = Color(0xFFD32F2F);

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _categorias = [];
  Map<int, double> _precios = {};
  Map<int, int> _stock = {};
  int? _pvId;
  int? _catId;
  String _query = '';
  bool _cargando = true;
  bool _procesando = false;
  final List<Map<String, dynamic>> _cart = [];

  double get _total => _cart.fold(0.0, (s, l) => s + ((l['price'] as double) * (l['qty'] as int)));
  int get _units => _cart.fold(0, (s, l) => s + (l['qty'] as int));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final db = context.read<DatabaseHelper>();
    final auth = context.read<AuthService>();
    _pvId = (auth.currentUser?['punto_venta_id_actual'] as int?) ??
        (auth.currentUser?['punto_venta_id'] as int?) ?? 0;
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    try {
      _productos = (await db.getProductos()).where((p) => (p['activo'] ?? 1) == 1).toList();
      _categorias = await db.getCategoriasProducto();
      if (_catId == null && _categorias.isNotEmpty) _catId = _categorias.first['id'] as int;
      await _cargarPreciosYStock(hoy);
    } catch (e) {
      _aviso('Error al cargar: $e', _red);
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarPreciosYStock(String hoy) async {
    if (_pvId == null || _pvId == 0) { _precios = {}; _stock = {}; return; }
    final db = context.read<DatabaseHelper>();
    final pr = await db.rawQuery('SELECT producto_id, precio FROM precios WHERE punto_venta_id = ?', [_pvId]);
    _precios = {for (final r in pr) (r['producto_id'] as int): (r['precio'] as num).toDouble()};
    final st = await db.rawQuery('SELECT producto_id, SUM(stock) as s FROM inventario WHERE punto_venta_id = ? AND fecha = ? GROUP BY producto_id', [_pvId, hoy]);
    _stock = {for (final r in st) (r['producto_id'] as int): ((r['s'] as num?)?.toInt() ?? 0)};
  }

  void _aviso(String msg, Color color, {String? accion, VoidCallback? onAccion}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      action: accion == null ? null : SnackBarAction(label: accion, textColor: Colors.white, onPressed: onAccion ?? () {}),
    ));
  }

  void _agregar(Map<String, dynamic> p) {
    final id = p['id'] as int;
    final precio = _precios[id] ?? 0.0;
    final disponible = (_stock[id] ?? 0) - _cart.where((l) => l['id'] == id).fold(0, (s, l) => s + (l['qty'] as int));
    if (precio <= 0) { _aviso('Sin precio para este PV', _red); return; }
    if (disponible <= 0) { _aviso('Sin stock de ${p['nombre']}', _red); return; }
    setState(() {
      final i = _cart.indexWhere((l) => l['id'] == id);
      if (i >= 0) { _cart[i]['qty'] = (_cart[i]['qty'] as int) + 1; }
      else { _cart.add({'id': id, 'codigo': p['codigo'], 'nombre': p['nombre'], 'price': precio, 'qty': 1}); }
    });
  }

  void _cambiarCantidad(int id, int delta) {
    setState(() {
      final i = _cart.indexWhere((l) => l['id'] == id);
      if (i < 0) return;
      _cart[i]['qty'] = (_cart[i]['qty'] as int) + delta;
      if ((_cart[i]['qty'] as int) <= 0) _cart.removeAt(i);
    });
  }

  void _vaciar() {
    if (_cart.isEmpty) return;
    final copia = List.of(_cart);
    setState(() => _cart.clear());
    _aviso('Carrito vaciado', _red, accion: 'DESHACER', onAccion: () => setState(() => _cart.addAll(copia)));
  }

  // FILTRO: solo muestra productos con stock positivo
  List<Map<String, dynamic>> get _visibles {
    final q = _query.trim().toLowerCase();
    return _productos.where((p) {
      if (_catId != null && p['categoria_id'] != _catId) return false;
      if ((_stock[p['id']] ?? 0) <= 0) return false; // OCULTA SIN STOCK
      if (q.isEmpty) return true;
      return '${p['codigo']} ${p['nombre']}'.toLowerCase().contains(q);
    }).toList();
  }

  bool get _sinStock => _pvId != null && _pvId != 0 && _stock.values.every((v) => v <= 0);

  Future<void> _cobrar(String tipo) async {
    if (_cart.isEmpty || _procesando) return;
    if (_pvId == null || _pvId == 0) { _aviso('PV sin asignar', _red); return; }
    String nombre = 'Consumidor Final', fono = '', dni = '';
    int? clienteId;
    double vuelto = 0.0;

    if (tipo == 'EFECTIVO') {
      final r = await _dialogoEfectivo();
      if (r == null) return;
      vuelto = r;
    } else if (tipo == 'FIADO' || tipo == 'ELECTRONICO') {
      final c = await _dialogoCliente(tipo);
      if (c == null) return;
      nombre = c['nombre'] ?? 'Consumidor Final';
      fono = c['fono'] ?? '';
      dni = c['dni'] ?? '';
      if (tipo == 'FIADO' && nombre == 'Consumidor Final') { _aviso('Para fiar se requiere nombre', _red); return; }
      if (dni.isNotEmpty) {
        final db = context.read<DatabaseHelper>();
        clienteId = await db.registrarClienteSiNoExiste(nombre, fono, dni);
      }
    }

    setState(() => _procesando = true);
    final db = context.read<DatabaseHelper>();
    final auth = context.read<AuthService>();
    try {
      final ventaData = {
        'cliente_id': clienteId,
        'usuario_id': auth.currentUser?['id'],
        'punto_venta_id': _pvId,
        'fecha': DateTime.now().toIso8601String(),
        'tipo_venta': tipo,
        'monto_total': double.parse(_total.toStringAsFixed(2)),
        'vuelto': double.parse(vuelto.toStringAsFixed(2)),
        'tiene_comprobante': tipo == 'ELECTRONICO' ? 1 : 0,
        'nombre_cliente': nombre,
        'telefono_cliente': fono,
        'dni_cliente': dni,
      };
      final items = _cart.map((l) => {'id': l['id'], 'qty': l['qty'], 'price': l['price']}).toList();
      await db.registrarVenta(ventaData, items, esCredito: tipo == 'FIADO');
      final monto = _total;
      setState(() { _cart.clear(); });
      await _cargarPreciosYStock(DateTime.now().toIso8601String().split('T')[0]);
      _aviso('Venta $tipo · S/ ${monto.toStringAsFixed(2)}', _green);
    } catch (e) {
      _aviso('No se pudo registrar: $e', _red);
    }
    if (mounted) setState(() => _procesando = false);
  }

  Future<double?> _dialogoEfectivo() {
    final ctrl = TextEditingController();
    double recibido = 0;
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setD) {
        final vuelto = recibido - _total;
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('COBRO EFECTIVO', style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Total: S/ ${_total.toStringAsFixed(2)}', style: const TextStyle(color: _amber, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Recibido'),
              onChanged: (v) => setD(() => recibido = double.tryParse(v.replaceAll(',', '.')) ?? 0)),
            const SizedBox(height: 8),
            Text('Vuelto: S/ ${vuelto < 0 ? 0 : vuelto.toStringAsFixed(2)}', style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, vuelto < 0 ? -1.0 : vuelto), child: const Text('COBRAR')),
          ],
        );
      }),
    ).then((v) => v == null || v < 0 ? null : v);
  }

  Future<Map<String, String>?> _dialogoCliente(String tipo) {
    final n = TextEditingController(), f = TextEditingController(), d = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(tipo == 'FIADO' ? 'VENTA FIADA' : 'DATOS COMANDA', style: const TextStyle(color: _amber, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: n, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombre *'))),
            IconButton(icon: const Icon(Icons.camera_alt, color: _amber), onPressed: () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerScreen()));
              if (r != null) { d.text = r['numero'] ?? ''; n.text = r['nombre'] ?? ''; }
            }),
          ]),
          const SizedBox(height: 8),
          TextField(controller: d, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'DNI')),
          const SizedBox(height: 8),
          TextField(controller: f, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Teléfono')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, {'nombre': n.text.trim().isEmpty ? 'Consumidor Final' : n.text.trim(), 'fono': f.text.trim(), 'dni': d.text.trim()}),
            child: const Text('ACEPTAR')),
        ],
      ),
    );
  }

  Widget _chip(String label, int? id) {
    final activo = _catId == id;
    return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
      label: Text(label, style: TextStyle(color: activo ? Colors.black : Colors.white70, fontWeight: FontWeight.w700)),
      selected: activo, selectedColor: _amber, backgroundColor: _surface, showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: activo ? _amber : const Color(0xFF333333))),
      onSelected: (_) => setState(() => _catId = id),
    ));
  }

  Widget _step(IconData icon, VoidCallback onTap) => Material(color: _card, borderRadius: BorderRadius.circular(8),
    child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, color: _amber, size: 16))));

  Widget _pay(String label, IconData icon, List<Color> grad, VoidCallback onTap) {
    final enabled = _cart.isNotEmpty && !_procesando;
    return Opacity(opacity: enabled ? 1 : .4, child: Material(borderRadius: BorderRadius.circular(12), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: enabled ? onTap : null,
      child: Ink(height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad)),
        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 6),
          Text(label, maxLines: 1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: .3)),
        ])))))));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: _amber));
    if (_sinStock) {
      return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inventory_2_outlined, size: 72, color: _amber),
        const SizedBox(height: 16),
        const Text('Aún no confirmaste el stock inicial de hoy', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Recibe el batch de abasto enviado por la BASE para habilitar la venta.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.black, minimumSize: const Size(0, 54)),
          onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => PvImportarEntradaScreen())); _cargar(); },
          icon: const Icon(Icons.download), label: const Text('RECIBIR ENTRADA DEL DÍA'))),
      ]));
    }
    return Container(color: _bg, child: SafeArea(bottom: false, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 6), child: Row(children: [
        const Expanded(child: Text('NUEVA VENTA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: .5))),
        Text('S/ ${_total.toStringAsFixed(2)}', style: const TextStyle(color: _amber, fontSize: 26, fontWeight: FontWeight.bold)),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(hintText: 'Buscar código o nombre…', prefixIcon: Icon(Icons.search, color: _amber, size: 20), filled: true, fillColor: _surface, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none)),
        onChanged: (v) => setState(() => _query = v))),
      SizedBox(height: 42, child: ListView(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), scrollDirection: Axis.horizontal, children: [
        _chip('TODAS', null),
        ..._categorias.map((c) => _chip(c['abreviatura'] ?? c['nombre'] ?? '', c['id'] as int)),
      ])),
      Expanded(child: _visibles.isEmpty
        ? const Center(child: Text('Sin productos con stock en esta categoría', style: TextStyle(color: Colors.white38)))
        : GridView.builder(padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .92),
            itemCount: _visibles.length,
            itemBuilder: (_, i) {
              final p = _visibles[i];
              final id = p['id'] as int;
              final precio = _precios[id];
              final st = _stock[id] ?? 0;
              final enCarro = _cart.where((l) => l['id'] == id).fold(0, (s, l) => s + (l['qty'] as int));
              final disp = st - enCarro;
              return Material(color: _card, borderRadius: BorderRadius.circular(14), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _agregar(p),
                child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(6)), child: Text(p['codigo'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
                    const Spacer(),
                    Text(p['categoria_abrev'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Text(p['nombre'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.15)),
                  const Spacer(),
                  Row(children: [
                    Expanded(child: Text(precio == null || precio <= 0 ? '—' : 'S/ ${precio.toStringAsFixed(2)}', style: TextStyle(color: precio == null || precio <= 0 ? Colors.white38 : _amber, fontSize: 17, fontWeight: FontWeight.bold))),
                    Text('st $st', style: TextStyle(color: disp <= 0 ? _red : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ]))));
            })),
      Container(decoration: BoxDecoration(color: _surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(top: BorderSide(color: _amber.withOpacity(.35)))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 6, 0), child: Row(children: [
            const Icon(Icons.shopping_cart, color: _amber, size: 20), const SizedBox(width: 8),
            Text('CARRITO ($_units)', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_cart.isNotEmpty) IconButton(visualDensity: VisualDensity.compact, onPressed: _vaciar, icon: const Icon(Icons.delete_sweep, color: _red, size: 20)),
          ])),
          ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .28), child: _cart.isEmpty
            ? const Padding(padding: EdgeInsets.fromLTRB(14, 6, 14, 12), child: Text('Toca un producto para agregarlo', style: TextStyle(color: Colors.white38, fontSize: 13)))
            : ListView.separated(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8), itemCount: _cart.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0xFF2E2E2E), height: 1),
                itemBuilder: (_, i) {
                  final l = _cart[i];
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                    Expanded(child: Text('${l['codigo']} · ${l['nombre']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    _step(Icons.remove, () => _cambiarCantidad(l['id'] as int, -1)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${l['qty']}', style: const TextStyle(color: _amber, fontSize: 14, fontWeight: FontWeight.bold))),
                    _step(Icons.add, () => _cambiarCantidad(l['id'] as int, 1)),
                    SizedBox(width: 62, child: Text('S/ ${((l['price'] as double) * (l['qty'] as int)).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ]));
                })),
        ])),
      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12), child: Row(children: [
        Expanded(child: _pay('EFECTIVO', Icons.payments, [_green, const Color(0xFF1B5E20)], () => _cobrar('EFECTIVO'))),
        const SizedBox(width: 10),
        Expanded(child: _pay('YAPE/PLIN', Icons.smartphone, [_yape, _plin], () => _cobrar('ELECTRONICO'))),
        const SizedBox(width: 10),
        Expanded(child: _pay('FIADO', Icons.handshake, [_red, const Color(0xFF8E0000)], () => _cobrar('FIADO'))),
      ])),
    ])));
  }
}