import 'package:flutter/material.dart'; // 1. Librería principal de Flutter.
import 'package:provider/provider.dart'; // 2. Para acceder al DatabaseHelper.
import '../services/database_helper.dart'; // 3. Importamos el servicio de base de datos.

class RentabilidadScreen extends StatelessWidget { // 4. Pantalla sin estado mutable.
  @override
  Widget build(BuildContext context) {
    final dbHelper = Provider.of<DatabaseHelper>(context); // 5. Obtenemos la instancia del helper.
    
    return Scaffold(
      appBar: AppBar(title: Text('MI RENTABILIDAD REAL'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      // 6. ¡CORRECCIÓN CLAVE! Cambiamos <List<Map...>> a <Map<String, dynamic>>
      body: FutureBuilder<Map<String, dynamic>>( 
        future: dbHelper.getResumenMensual(), // 7. Llamamos al método corregido en el helper.
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { // 8. Verificamos si aún está cargando.
            return Center(child: CircularProgressIndicator(color: Colors.yellow)); // 9. Spinner de carga.
          }
          if (!snapshot.hasData || snapshot.hasError) { // 10. Verificamos si hay datos o errores.
            return Center(child: Text('Error al cargar datos', style: TextStyle(color: Colors.red)));
          }
          
          var data = snapshot.data!; // 11. ¡CORRECCIÓN! Ya no usamos .first, porque es un Mapa, no una Lista.
          
          return Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESUMEN DEL MES', style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 30),
                // 12. Las claves ahora coinciden exactamente con lo que devuelve el helper corregido.
                _buildRow('VENTAS TOTALES', data['ventas'] ?? 0.0, Colors.green), 
                _buildRow('GASTOS OPERATIVOS', data['gastos'] ?? 0.0, Colors.red),
                Divider(color: Colors.white),
                _buildRow('UTILIDAD NETA (CAJA LIBRE)', data['utilidad'] ?? 0.0, Colors.white, isBig: true),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildRow(String label, double amount, Color color, {bool isBig = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
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