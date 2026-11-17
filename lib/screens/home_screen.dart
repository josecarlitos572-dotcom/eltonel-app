// ============================================================
// home_screen.dart — Navegación principal de El Tonel
// Tab inicial por rol · Logo en AppBar · Banner de estado
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'venta_screen.dart';
import 'admin_dashboard_screen.dart';
import 'cierre_caja_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;                              // Tab seleccionado
  bool _aperturado = false;                       // Stock inicial confirmado hoy
  String? _batchPendiente;                        // Mensaje de batch por recibir
  static const Color _amber = Color(0xFFFFC107);  // Acento de marca
  static const Color _bg = Color(0xFF121212);     // Fondo general
  static const Color _surface = Color(0xFF1E1E1E);// Superficie

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluarEstado());
  }

  // Evalúa si el vendedor ya confirmó el stock inicial del día.
  Future<void> _evaluarEstado() async {
    final db = context.read<DatabaseHelper>();
    final auth = context.read<AuthService>();
    final rol = auth.currentUser?['rol'] as String?;
    final pvId = auth.currentUser?['punto_venta_id_actual'] as int?;
    if (rol != 'VENDEDOR' || pvId == null || pvId == 0) {
      setState(() { _aperturado = true; }); // ADMIN no requiere apertura
      return;
    }
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final stock = await db.rawQuery(
      'SELECT SUM(stock) as total FROM inventario WHERE punto_venta_id = ? AND fecha = ?',
      [pvId, hoy],
    );
    final total = (stock.first['total'] as num?)?.toInt() ?? 0;
    setState(() { _aperturado = total > 0; }); // Hay stock → puede vender
  }

  // Tabs disponibles según rol.
  List<Widget> get _tabs {
    final rol = context.read<AuthService>().currentUser?['rol'] as String?;
    if (rol == 'ADMIN') {
      return [
        AdminDashboardScreen(),
        VentaScreen(),
        CierreCajaScreen(),
      ];
    }
    return [
      VentaScreen(),
      CierreCajaScreen(),
    ];
  }

  // Etiquetas de los tabs según rol.
  List<String> get _labels {
    final rol = context.read<AuthService>().currentUser?['rol'] as String?;
    if (rol == 'ADMIN') return ['DASHBOARD', 'VENDER', 'CIERRE'];
    return ['VENDER', 'CIERRE'];
  }

  // Tab inicial según rol.
  int get _tabInicial {
    final rol = context.read<AuthService>().currentUser?['rol'] as String?;
    return rol == 'ADMIN' ? 0 : 0; // ADMIN arranca en DASHBOARD
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final nombre = '${auth.currentUser?['nombres'] ?? ''} ${auth.currentUser?['apellidos'] ?? ''}'.trim();
    final rol = auth.currentUser?['rol'] as String?;
    final pvCodigo = auth.currentUser?['punto_venta_id_actual'] == 0
        ? 'ADMIN'
        : 'PV ${auth.currentUser?['punto_venta_id_actual'] ?? '?'}';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Row(children: [
          // Logo real desde assets
          Image.asset('assets/logo/eltonel_logo.png', height: 32, width: 32, errorBuilder: (_, __, ___) => const Icon(Icons.breakfast_dining, color: _amber, size: 32)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('El Tonel', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('$nombre · $rol · $pvCodigo', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: _amber),
            onPressed: () => _confirmarLogout(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      // Banner de estado: apertura de día o batch pendiente
      body: Column(children: [
        if (!_aperturado && rol == 'VENDEDOR')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFFFA000),
            child: Row(children: [
              const Icon(Icons.warning_amber, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Debes confirmar el stock inicial del día antes de vender.',
                  style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        Expanded(child: _tabs[_tabIndex]),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: _surface,
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _amber,
        unselectedItemColor: Colors.white54,
        items: _labels.map((l) => BottomNavigationBarItem(
          icon: Icon(l == 'DASHBOARD' ? Icons.dashboard : l == 'VENDER' ? Icons.point_of_sale : Icons.lock_clock),
          label: l,
        )).toList(),
      ),
    );
  }

  // Logout con confirmación.
  void _confirmarLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('¿Cerrar sesión?', style: TextStyle(color: Colors.white)),
        content: const Text('Se cerrará la sesión en este dispositivo.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.black),
            onPressed: () {
              context.read<AuthService>().logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
            child: const Text('SALIR'),
          ),
        ],
      ),
    );
  }
}