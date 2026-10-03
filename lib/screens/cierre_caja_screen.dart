import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/database_helper.dart'; // REM: Servicio de base de datos local
import '../services/auth_service.dart'; // REM: Servicio de autenticación de usuarios
import 'home_screen.dart'; // REM: Pantalla de menú principal para retorno tras cierre

class CierreCajaScreen extends StatefulWidget { // REM: Pantalla de cierre de jornada con estado dinámico
  @override
  _CierreCajaScreenState createState() => _CierreCajaScreenState(); // REM: Crea el estado de la pantalla
}

class _CierreCajaScreenState extends State<CierreCajaScreen> { // REM: Lógica interna del cierre de caja
  final TextEditingController _conteoFisicoCtrl = TextEditingController(); // REM: Controlador para el conteo real de efectivo en gaveta
  final TextEditingController _desmedrosCtrl = TextEditingController(text: '0'); // REM: Controlador para valor de mercancía dañada/perdida
  final TextEditingController _obsCtrl = TextEditingController(); // REM: Controlador para observaciones del cierre
  
  double _ventasDelDia = 0; // REM: Total de ventas registradas hoy
  double _gastosDelDia = 0; // REM: Total de gastos operativos registrados hoy
  double _saldoInicial = 0; // REM: Monto de cambio inicial registrado en apertura
  bool _isLoading = true; // REM: Indicador de carga mientras se obtienen datos

  @override
  void initState() { // REM: Se ejecuta al montar la pantalla
    super.initState(); // REM: Llama al initState del padre
    _cargarDatosDelDia(); // REM: Carga los totales del día desde la base de datos
  }

  Future<void> _cargarDatosDelDia() async { // REM: Obtiene resumen financiero del día
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final db = await dbHelper.database; // REM: Obtiene instancia de base de datos
    final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio de autenticación
    final hoy = DateTime.now().toIso8601String().split('T')[0]; // REM: Fecha actual en formato YYYY-MM-DD
    final pvId = auth.currentUser?['punto_venta_id']; // REM: ID del punto de venta del usuario actual

    var v = await db.rawQuery('SELECT SUM(monto_total) as t FROM ventas WHERE fecha LIKE ? AND punto_venta_id = ?', ['$hoy%', pvId]); // REM: Suma todas las ventas del día en este punto
    var g = await db.rawQuery('SELECT SUM(monto) as t FROM gastos_internos WHERE fecha LIKE ? AND usuario_id IN (SELECT id FROM personal WHERE punto_venta_id = ?)', ['$hoy%', pvId]); // REM: Suma gastos del personal de este punto
    var a = await db.query('aperturas_caja', where: 'fecha = ? AND punto_venta_id = ?', whereArgs: [hoy, pvId]); // REM: Busca la apertura de caja de hoy

    setState(() { // REM: Actualiza el estado con los datos obtenidos
      _ventasDelDia = v.first['t'] == null ? 0 : (v.first['t'] as num).toDouble(); // REM: Asigna total de ventas (0 si no hay)
      _gastosDelDia = g.first['t'] == null ? 0 : (g.first['t'] as num).toDouble(); // REM: Asigna total de gastos (0 si no hay)
      _saldoInicial = a.isEmpty ? 0 : (a.first['saldo_inicial'] as num).toDouble(); // REM: Asigna saldo inicial (0 si no hay apertura)
      _isLoading = false; // REM: Marca que la carga terminó
    });
  }

  Future<void> _ejecutarCierre() async { // REM: Procesa el cierre final de la jornada
    if (_conteoFisicoCtrl.text.isEmpty) return; // REM: Si no hay conteo físico, no hace nada
    
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final db = await dbHelper.database; // REM: Obtiene instancia de base de datos
    final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio de autenticación
    final hoy = DateTime.now().toIso8601String(); // REM: Fecha y hora actual completa
    final pvId = auth.currentUser?['punto_venta_id']; // REM: ID del punto de venta
    final userId = auth.currentUser?['id']; // REM: ID del usuario que cierra

    double conteo = double.tryParse(_conteoFisicoCtrl.text) ?? 0; // REM: Convierte texto a número (dinero contado físicamente)
    double desmedros = double.tryParse(_desmedrosCtrl.text) ?? 0; // REM: Convierte texto a número (valor de pérdidas)
    
    double teorico = _saldoInicial + _ventasDelDia - _gastosDelDia - desmedros; // REM: Calcula cuánto debería haber en caja según registros
    double diferencia = conteo - teorico; // REM: Calcula diferencia entre lo real y lo teórico (positivo=sobra, negativo=falta)

    await db.insert('cierres_caja', { // REM: Guarda el registro de cierre en la base de datos
      'fecha': hoy, // REM: Fecha y hora del cierre
      'punto_venta_id': pvId, // REM: Punto de venta que cierra
      'personal_id': userId, // REM: Usuario que ejecuta el cierre
      'saldo_inicial': _saldoInicial, // REM: Con cuánto dinero se empezó
      'total_ventas': _ventasDelDia, // REM: Cuánto se vendió en el día
      'total_gastos_manuales': _gastosDelDia, // REM: Cuánto se gastó en el día
      'saldo_teorico': teorico, // REM: Cuánto debería haber según registros
      'saldo_real_contado': conteo, // REM: Cuánto hay realmente en la gaveta
      'diferencia': diferencia, // REM: Diferencia (cuadre o descuadre)
      'observaciones': '${_obsCtrl.text} | DESMEDROS: S/.$desmedros' // REM: Notas y valor de desmedros
    });

    await db.rawUpdate('UPDATE inventario SET stock = 0 WHERE punto_venta_id = ? AND fecha = ?', [pvId, DateTime.now().toIso8601String().split('T')[0]]); // REM: RESETEA EL STOCK A CERO para el siguiente día

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen())); // REM: Vuelve al menú principal
  }

  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual
    if (_isLoading) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow))); // REM: Muestra spinner mientras carga
    
    double teorico = _saldoInicial + _ventasDelDia - _gastosDelDia - (double.tryParse(_desmedrosCtrl.text) ?? 0); // REM: Calcula saldo teórico en tiempo real

    return Scaffold( // REM: Estructura de la pantalla
      appBar: AppBar(title: Text('CIERRE DE JORNADA'), backgroundColor: Colors.black), // REM: Barra superior
      backgroundColor: Colors.black, // REM: Fondo negro
      body: Padding( // REM: Margen interno
        padding: EdgeInsets.all(20), // REM: 20 píxeles de margen
        child: ListView( // REM: Lista scrollable
          children: [
            Text('RESUMEN DEL DÍA', style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 20)), // REM: Título amarillo
            SizedBox(height: 10), // REM: Espacio vertical
            _row('Saldo Inicial:', 'S/. ${_saldoInicial.toStringAsFixed(2)}', Colors.white), // REM: Fila con saldo inicial
            _row('Ventas:', 'S/. ${_ventasDelDia.toStringAsFixed(2)}', Colors.green), // REM: Fila con ventas en verde
            _row('Gastos:', 'S/. ${_gastosDelDia.toStringAsFixed(2)}', Colors.red), // REM: Fila con gastos en rojo
            Divider(color: Colors.grey[800]), // REM: Línea separadora
            
            SizedBox(height: 20), // REM: Espacio vertical
            TextField(controller: _desmedrosCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Desmedros (S/.)', labelStyle: TextStyle(color: Colors.orange)), style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Campo para valor de pérdidas
            SizedBox(height: 15), // REM: Espacio vertical
            TextField(controller: _conteoFisicoCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Conteo Físico Actual', labelStyle: TextStyle(color: Colors.yellow)), style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Campo para dinero real contado
            SizedBox(height: 15), // REM: Espacio vertical
            TextField(controller: _obsCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Observaciones', labelStyle: TextStyle(color: Colors.white)), style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Campo para notas
            
            SizedBox(height: 30), // REM: Espacio vertical
            Container(padding: EdgeInsets.all(15), color: Colors.grey[900], child: Column( // REM: Caja de resultados con fondo gris
              children: [
                _row('Saldo Teórico:', 'S/. ${teorico.toStringAsFixed(2)}', Colors.white), // REM: Cuánto debería haber
                _row('Diferencia:', 'S/. ${(double.tryParse(_conteoFisicoCtrl.text) ?? 0 - teorico).toStringAsFixed(2)}', 
                  (double.tryParse(_conteoFisicoCtrl.text) ?? 0) >= teorico ? Colors.green : Colors.red), // REM: Diferencia (verde si cuadra o sobra, rojo si falta)
              ],
            )),
            SizedBox(height: 30), // REM: Espacio vertical
            ElevatedButton(onPressed: _ejecutarCierre, child: Text('CONFIRMAR CIERRE Y RESET STOCK'), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60))) // REM: Botón final de cierre
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v, Color c) => Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ // REM: Función auxiliar para crear filas de datos
    Text(l, style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 16)), // REM: Etiqueta en blanco
    Text(v, style: TextStyle(color: c, fontFamily: 'CourierNew', fontSize: 16, fontWeight: FontWeight.bold)) // REM: Valor con color dinámico
  ]));
}
