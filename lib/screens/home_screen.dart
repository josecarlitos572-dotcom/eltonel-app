import 'package:flutter/material.dart';
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
    // Si es vendedor, pon false
    final bool isAdmin = true; 

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

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale, size: 30),
            label: 'Vender',
          ),
          if (isAdmin) const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings, size: 30),
            label: 'Admin',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.money, size: 30),
            label: 'Cierre',
          ),
        ],
      ),
    );
  }
}