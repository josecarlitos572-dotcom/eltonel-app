import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/database_helper.dart'; // REM: Servicio de base de datos local

class CxcScreen extends StatelessWidget { // REM: Pantalla de consulta de cuentas por cobrar sin estado mutable
  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual
    final dbHelper = Provider.of<DatabaseHelper>(context); // REM: Obtiene el servicio de base de datos
    
    return Scaffold( // REM: Estructura base de la pantalla
      appBar: AppBar(title: Text('CUENTAS POR COBRAR'), backgroundColor: Colors.black), // REM: Barra superior con título
      backgroundColor: Colors.black, // REM: Fondo negro absoluto
      body: FutureBuilder<List<Map<String, dynamic>>>( // REM: Widget que espera datos asíncronos
        future: dbHelper.database.then((db) => db.rawQuery(''' // REM: Ejecuta consulta SQL directa
          SELECT nombre_cliente, SUM(monto_total) as saldo_total, MAX(fecha_vencimiento) as ultimo_vencimiento 
          FROM ventas 
          WHERE tipo_venta = 'credito' AND fecha_vencimiento >= ? 
          GROUP BY LOWER(nombre_cliente) 
          ORDER BY saldo_total DESC
        ''', [DateTime.now().toIso8601String().split('T')[0]])), // REM: Filtra créditos activos (no vencidos) y ordena por monto
        builder: (ctx, snapshot) { // REM: Constructor que renderiza según el estado de los datos
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.yellow)); // REM: Muestra spinner mientras carga
          return ListView.builder( // REM: Lista scrollable de deudores
            itemCount: snapshot.data!.length, // REM: Cantidad de clientes con deuda
            itemBuilder: (ctx, i) { // REM: Constructor de cada ítem
              var v = snapshot.data![i]; // REM: Cliente actual
              return ListTile( // REM: Ítem de lista
                title: Text('${v['nombre_cliente']}', style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Nombre del cliente en blanco
                subtitle: Text('Vence: ${v['ultimo_vencimiento']}', style: TextStyle(color: Colors.grey)), // REM: Fecha de vencimiento en gris
                trailing: Text('S/. ${v['saldo_total'].toStringAsFixed(2)}', style: TextStyle(color: Colors.orange, fontFamily: 'CourierNew', fontSize: 16)), // REM: Monto de deuda en naranja
              );
            },
          );
        },
      ),
    );
  }
}
