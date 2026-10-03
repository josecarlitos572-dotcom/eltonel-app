import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/database_helper.dart'; // REM: Servicio de base de datos local

class RentabilidadScreen extends StatelessWidget { // REM: Pantalla de solo lectura sin estado mutable
  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual
    final dbHelper = Provider.of<DatabaseHelper>(context); // REM: Obtiene el servicio de base de datos
    
    return Scaffold( // REM: Estructura base de la pantalla
      appBar: AppBar(title: Text('MI RENTABILIDAD REAL'), backgroundColor: Colors.black), // REM: Barra superior con título
      backgroundColor: Colors.black, // REM: Fondo negro absoluto
      body: FutureBuilder<List<Map<String, dynamic>>>( // REM: Widget que espera datos asíncronos
        future: dbHelper.getResumenMensual(), // REM: Llama a la función que calcula el resumen del mes
        builder: (ctx, snapshot) { // REM: Constructor que renderiza según el estado de los datos
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.yellow)); // REM: Muestra spinner mientras carga
          var data = snapshot.data!.first; // REM: Obtiene el primer (y único) resultado del resumen
          return Padding( // REM: Margen interno
            padding: EdgeInsets.all(20), // REM: 20 píxeles de margen
            child: Column( // REM: Columna vertical de resultados
              crossAxisAlignment: CrossAxisAlignment.start, // REM: Alineación a la izquierda
              children: [
                Text('RESUMEN DEL MES', style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)), // REM: Título amarillo grande
                SizedBox(height: 30), // REM: Espacio vertical de 30 píxeles
                _buildRow('VENTAS TOTALES', data['ventas'], Colors.green), // REM: Fila de ventas en verde
                _buildRow('GASTOS OPERATIVOS', data['gastos'], Colors.red), // REM: Fila de gastos en rojo
                Divider(color: Colors.white), // REM: Línea separadora blanca
                _buildRow('UTILIDAD NETA (CAJA LIBRE)', data['utilidad'], Colors.white, isBig: true), // REM: Fila de utilidad en blanco grande
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildRow(String label, double amount, Color color, {bool isBig = false}) { // REM: Función auxiliar para crear filas de datos
    return Padding( // REM: Margen vertical
      padding: EdgeInsets.symmetric(vertical: 10), // REM: 10 píxeles arriba y abajo
      child: Row( // REM: Fila horizontal distribuida
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // REM: Espaciado entre etiqueta y valor
        children: [
          Text(label, style: TextStyle(color: Colors.white, fontSize: isBig ? 20 : 16, fontFamily: 'CourierNew')), // REM: Etiqueta en blanco Courier
          Text('S/. ${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: isBig ? 24 : 18, fontWeight: FontWeight.bold, fontFamily: 'CourierNew')), // REM: Valor con color dinámico y tamaño condicional
        ],
      ),
    );
  }
}
