import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// IMPORTANTE: Asegúrate de que estas rutas coincidan con tus archivos reales
// import 'venta_screen.dart';
// import 'inventario_screen.dart';
// import 'caja_screen.dart';
// import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // ASUMIENDO QUE TIENES UN PROVIDER DE AUTH O LEES EL ROL DE SHAREDPREFERENCES
    // CAMBIA ESTO POR TU LÓGICA REAL:
    final bool isAdmin = true; // Si es vendedor, pon false

    final List<Widget> _screens = isAdmin 
      ? [
          VentaScreen(),       
          InventarioScreen(),  
          CajaScreen(),        
          AdminScreen(),       
        ]
      : [
          VentaScreen(),       
          CajaScreen(),        
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
            icon: Icon(Icons.inventory, size: 30),
            label: 'Stock',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.money, size: 30),
            label: 'Caja',
          ),
          if (isAdmin) const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings, size: 30),
            label: 'Admin',
          ),
        ],
      ),
    );
  }
}