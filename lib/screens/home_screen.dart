import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'venta_screen.dart';
import 'cierre_caja_screen.dart';
import 'admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final bool isAdmin = auth.currentUser?['rol'] == 'ADMIN';

    final List<Widget> _screens = isAdmin 
      ? [
          VentaScreen(),       
          AdminDashboardScreen(),  
          CierreCajaScreen(),        
        ]
      : [
          VentaScreen(),       
          CierreCajaScreen(),        
        ];

    // Asegurar que el índice no se salga de rango si cambia el rol
    if (_selectedIndex >= _screens.length) _selectedIndex = 0;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFC107),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontFamily: 'CourierNew', fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'CourierNew', fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale, size: 28),
              label: 'VENDER',
            ),
            if (isAdmin) const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard, size: 28),
              label: 'DASHBOARD',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.output, size: 28),
              label: 'CIERRE',
            ),
          ],
        ),
      ),
    );
  }
}