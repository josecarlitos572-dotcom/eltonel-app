import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class RentabilidadScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dbHelper = Provider.of<DatabaseHelper>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('MI RENTABILIDAD REAL'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, dynamic>>(
        future: dbHelper.getResumenMensual(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.yellow));
          }
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: Text('Error al cargar datos', style: TextStyle(color: Colors.red)));
          }
          
          var data = snapshot.data!;
          
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESUMEN DEL MES', style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                _buildRow('VENTAS TOTALES', data['total_ventas'] ?? 0.0, Colors.green),
                _buildRow('GASTOS OPERATIVOS', data['total_gastos'] ?? 0.0, Colors.red),
                const Divider(color: Colors.white),
                _buildRow('UTILIDAD NETA (CAJA LIBRE)', data['rentabilidad'] ?? 0.0, Colors.white, isBig: true),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildRow(String label, double amount, Color color, {bool isBig = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white, fontSize: isBig ? 20 : 16, fontFamily: 'CourierNew')),
          Text('S/. ${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: isBig ? 24 : 18, fontWeight: FontWeight.bold, fontFamily: 'CourierNew')),
        ],
      ),
    );
  }
}