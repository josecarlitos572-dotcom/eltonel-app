import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/database_helper.dart'; // REM: Servicio de base de datos local

class AdminPersonalScreen extends StatefulWidget { // REM: Pantalla de gestión de personal con estado dinámico
  @override
  _AdminPersonalScreenState createState() => _AdminPersonalScreenState(); // REM: Crea el estado de la pantalla
}

class _AdminPersonalScreenState extends State<AdminPersonalScreen> { // REM: Lógica interna de gestión de personal
  final TextEditingController _dniCtrl = TextEditingController(); // REM: Controlador para el campo DNI
  final TextEditingController _passCtrl = TextEditingController(); // REM: Controlador para el campo contraseña
  final TextEditingController _nombresCtrl = TextEditingController(); // REM: Controlador para el campo nombres
  final TextEditingController _apellidosCtrl = TextEditingController(); // REM: Controlador para el campo apellidos
  String _rolSeleccionado = 'vendedor'; // REM: Rol por defecto al crear nuevo usuario
  int _pvSeleccionado = 1; // REM: Punto de venta por defecto (Santa Rosa)

  Future<void> _crearUsuario() async { // REM: Función para crear nuevo usuario en la base de datos
    if (_dniCtrl.text.isEmpty) return; // REM: Si el DNI está vacío, no hace nada
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final db = await dbHelper.database; // REM: Obtiene instancia de base de datos
    
    try { // REM: Intenta insertar el nuevo usuario
      await db.insert('personal', { // REM: Inserta en tabla personal
        'dni': _dniCtrl.text, // REM: DNI único del usuario
        'password': _passCtrl.text, // REM: Contraseña del usuario
        'nombres': _nombresCtrl.text, // REM: Nombres del usuario
        'apellidos': _apellidosCtrl.text, // REM: Apellidos del usuario
        'rol': _rolSeleccionado, // REM: Rol asignado (vendedor, supervisor, admin)
        'punto_venta_id': _rolSeleccionado == 'admin' ? 0 : _pvSeleccionado, // REM: Si es admin, punto 0; si no, el seleccionado
        'activo': 1 // REM: Estado activo por defecto
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Personal Registrado'), backgroundColor: Colors.green)); // REM: Muestra mensaje de éxito en verde
      setState(() { _dniCtrl.clear(); _passCtrl.clear(); _nombresCtrl.clear(); _apellidosCtrl.clear(); }); // REM: Limpia los campos de entrada
    } catch (e) { // REM: Si hay error (ej: DNI duplicado)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: DNI ya existe'), backgroundColor: Colors.red)); // REM: Muestra error en rojo
    }
  }

  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual de la pantalla
    return Scaffold( // REM: Estructura base de la pantalla
      appBar: AppBar(title: Text('GESTIÓN DE PERSONAL'), backgroundColor: Colors.black), // REM: Barra superior con título
      backgroundColor: Colors.black, // REM: Fondo negro absoluto
      body: Padding( // REM: Margen interno
        padding: EdgeInsets.all(20), // REM: 20 píxeles de margen
        child: ListView( // REM: Lista scrollable vertical
          children: [
            Text('REGISTRAR NUEVO OPERADOR', style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 20)), // REM: Título amarillo grande
            SizedBox(height: 20), // REM: Espacio vertical de 20 píxeles
            TextField( // REM: Campo de DNI
              controller: _dniCtrl, // REM: Vincula el controlador
              keyboardType: TextInputType.number, // REM: Muestra teclado numérico
              decoration: InputDecoration(
                labelText: 'DNI', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.white) // REM: Color blanco para la etiqueta
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 15), // REM: Espacio vertical de 15 píxeles
            TextField( // REM: Campo de contraseña
              controller: _passCtrl, // REM: Vincula el controlador
              decoration: InputDecoration(
                labelText: 'Contraseña', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.white) // REM: Color blanco para la etiqueta
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 15), // REM: Espacio vertical de 15 píxeles
            TextField( // REM: Campo de nombres
              controller: _nombresCtrl, // REM: Vincula el controlador
              decoration: InputDecoration(
                labelText: 'Nombres', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.white) // REM: Color blanco para la etiqueta
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 15), // REM: Espacio vertical de 15 píxeles
            TextField( // REM: Campo de apellidos
              controller: _apellidosCtrl, // REM: Vincula el controlador
              decoration: InputDecoration(
                labelText: 'Apellidos', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.white) // REM: Color blanco para la etiqueta
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 15), // REM: Espacio vertical de 15 píxeles
            DropdownButton<String>( // REM: Selector desplegable de rol
              value: _rolSeleccionado, // REM: Valor actualmente seleccionado
              dropdownColor: Colors.black, // REM: Color de fondo del menú desplegable
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Estilo de texto blanco Courier
              items: ['vendedor', 'supervisor', 'admin'].map((val) => DropdownMenuItem(value: val, child: Text(val.toUpperCase()))).toList(), // REM: Genera las opciones de rol en mayúsculas
              onChanged: (val) => setState(() => _rolSeleccionado = val!), // REM: Actualiza el rol seleccionado
            ),
            if (_rolSeleccionado != 'admin') ...[ // REM: Solo muestra selector de punto si NO es admin
              SizedBox(height: 15), // REM: Espacio vertical de 15 píxeles
              DropdownButton<int>( // REM: Selector desplegable de punto de venta
                value: _pvSeleccionado, // REM: Valor actualmente seleccionado
                dropdownColor: Colors.black, // REM: Color de fondo del menú desplegable
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Estilo de texto blanco Courier
                items: [ // REM: Opciones de puntos de venta
                  DropdownMenuItem(value: 1, child: Text('Santa Rosa')), // REM: Punto SR1
                  DropdownMenuItem(value: 2, child: Text('Víctor Raúl 1')), // REM: Punto VR1
                  DropdownMenuItem(value: 3, child: Text('Víctor Raúl 2')), // REM: Punto VR2
                ].toList(),
                onChanged: (val) => setState(() => _pvSeleccionado = val!), // REM: Actualiza el punto seleccionado
              ),
            ],
            SizedBox(height: 30), // REM: Espacio vertical de 30 píxeles
            ElevatedButton( // REM: Botón de acción principal
              onPressed: _crearUsuario, // REM: Ejecuta la función de creación al presionar
              child: Text('GUARDAR PERSONAL'), // REM: Texto del botón
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow, // REM: Fondo amarillo
                minimumSize: Size(double.infinity, 50) // REM: Ancho completo, alto 50
              )
            )
          ],
        ),
      ),
    );
  }
}
