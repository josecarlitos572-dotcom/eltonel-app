import 'package:flutter/material.dart';

class PersonalScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PERSONAL')),
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'EN CONSTRUCCIÓN\n(Bloque 1.3)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
      ),
    );
  }
}