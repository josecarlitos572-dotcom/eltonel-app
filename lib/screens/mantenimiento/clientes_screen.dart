import 'package:flutter/material.dart';

class ClientesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('CLIENTES')),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'EN CONSTRUCCIÓN\n(Bloque 1.4)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
      ),
    );
  }
}