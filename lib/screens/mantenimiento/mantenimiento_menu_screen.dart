import 'package:flutter/material.dart';
import 'categorias_producto_screen.dart';
import 'productos_screen.dart';
import 'personal_screen.dart';
import 'clientes_screen.dart';
import 'categorias_gasto_screen.dart';
import 'parametros_screen.dart';

class MantenimientoMenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MANTENIMIENTO')),
      backgroundColor: Colors.black,
      body: ListView(
        padding: EdgeInsets.all(15),
        children: [
          _boton(context, 'PRODUCTOS Y PRECIOS', Icons.fastfood,
              () => _ir(context, ProductosScreen())),
          _boton(context, 'CATEGORÍAS DE PRODUCTO', Icons.category,
              () => _ir(context, CategoriasProductoScreen())),
          _boton(context, 'PERSONAL', Icons.people,
              () => _ir(context, PersonalScreen())),
          _boton(context, 'CLIENTES', Icons.person_outline,
              () => _ir(context, ClientesScreen())),
          _boton(context, 'CATEGORÍAS DE GASTO', Icons.receipt,
              () => _ir(context, CategoriasGastoScreen())),
          _boton(context, 'PARÁMETROS DEL SISTEMA', Icons.settings,
              () => _ir(context, ParametrosScreen())),
        ],
      ),
    );
  }

  void _ir(BuildContext context, Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  Widget _boton(BuildContext context, String texto, IconData icono, VoidCallback accion) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        height: 70,
        child: ElevatedButton.icon(
          onPressed: accion,
          icon: Icon(icono, color: Colors.black, size: 32),
          label: Text(
            texto,
            style: TextStyle(
              fontFamily: 'CourierNew',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}