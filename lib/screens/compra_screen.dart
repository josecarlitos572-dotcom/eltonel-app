import 'package:flutter/material.dart'; // 1. Librería principal de Flutter.
import 'package:provider/provider.dart'; // 2. Para acceder a los servicios (DatabaseHelper, AuthService).
import '../services/database_helper.dart'; // 3. Importamos el helper de base de datos.
import '../services/auth_service.dart'; // 4. Importamos el servicio de autenticación.

class CompraScreen extends StatefulWidget { // 5. Pantalla con estado (porque los campos de texto cambian).
  @override
  _CompraScreenState createState() => _CompraScreenState(); // 6. Creamos el estado.
}

class _CompraScreenState extends State<CompraScreen> {
  final TextEditingController _montoCtrl = TextEditingController(); // 7. Controlador para el campo de monto.
  final TextEditingController _descCtrl = TextEditingController(); // 8. Controlador para la descripción.
  int _categoriaId = 1; // 9. Categoría seleccionada por defecto.
  List<Map<String, dynamic>> _categorias = []; // 10. Lista para guardar las categorías de la BD.
  int tieneComprobante = 0; // 11. Bandera para saber si hay comprobante (0 = No, 1 = Sí).

  @override
  void initState() {
    super.initState(); // 12. Llamamos al init de la clase padre.
    _cargarCategorias(); // 13. Cargamos las categorías al iniciar la pantalla.
  }

  Future<void> _cargarCategorias() async {
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // 14. Obtenemos el helper sin escuchar cambios.
    final db = await dbHelper.database; // 15. Esperamos a que la BD esté lista.
    var cats = await db.query('categorias_gasto', where: 'activo = 1'); // 16. Consultamos solo las categorías activas.
    setState(() {
      _categorias = cats; // 17. Guardamos las categorías en el estado.
      if (cats.isNotEmpty) {
        _categoriaId = cats.first['id'] as int; // 18. Seleccionamos la primera por defecto.
      }
    });
  }

  void _guardarGasto() async {
    if (_montoCtrl.text.isEmpty) return; // 19. Si el monto está vacío, no hacemos nada.
    
    double monto = double.tryParse(_montoCtrl.text) ?? 0; // 20. Convertimos el texto a número decimal.
    var catSeleccionada = _categorias.firstWhere((c) => c['id'] == _categoriaId); // 21. Buscamos la categoría elegida.
    double limite = (catSeleccionada['limite_max'] as num?)?.toDouble() ?? 0.0; // 22. Obtenemos su límite máximo.
    
    if (monto > limite) { // 23. Validamos si el monto supera el límite.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LÍMITE EXCEDIDO. Máximo para ${catSeleccionada['nombre']} es S/. $limite'), backgroundColor: Colors.red)
      );
      return; // 24. Detenemos la ejecución.
    }

    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // 25. Obtenemos el helper nuevamente.
    final auth = Provider.of<AuthService>(context, listen: false); // 26. Obtenemos el servicio de auth.
    int usuarioId = auth.currentUser?['id'] as int? ?? 1; // 27. ID del usuario actual (o 1 por defecto).
    String nombreCategoria = catSeleccionada['nombre'] as String; // 28. Nombre de la categoría en texto.

    // 29. ¡CORRECCIÓN CLAVE! Creamos un Mapa con todos los datos, tal como lo espera el helper.
    final datosGasto = {
      'fecha': DateTime.now().toIso8601String().split('T')[0], // 30. Fecha de hoy (YYYY-MM-DD).
      'categoria': nombreCategoria, // 31. Nombre de la categoría.
      'descripcion': _descCtrl.text, // 32. Descripción escrita por el usuario.
      'monto': monto, // 33. Monto numérico.
      'tiene_comprobante': tieneComprobante, // 34. Bandera de comprobante (0 o 1).
      'usuario_id': usuarioId, // 35. ID del usuario que registra.
    };

    // 36. Llamamos al método pasándole UN SOLO argumento (el Mapa).
    await dbHelper.registrarGasto(datosGasto); 
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gasto Registrado Correctamente'), backgroundColor: Colors.green)
    );
    setState(() { 
      _montoCtrl.clear(); // 37. Limpiamos el campo de monto.
      _descCtrl.clear(); // 38. Limpiamos el campo de descripción.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('REGISTRAR GASTO OPERATIVO'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButton<int>(
              value: _categoriaId,
              dropdownColor: Colors.black,
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              items: _categorias.map<DropdownMenuItem<int>>((val) => DropdownMenuItem<int>(
                value: val['id'] as int,
                child: Text(val['nombre'] as String),
              )).toList(),
              onChanged: (val) => setState(() => _categoriaId = val!),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(labelText: 'Descripción Detallada', labelStyle: TextStyle(color: Colors.white)),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _montoCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Monto S/.', labelStyle: TextStyle(color: Colors.white)),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿Tiene Comprobante?', style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
                Switch(
                  value: tieneComprobante == 1,
                  onChanged: (val) => setState(() => tieneComprobante = val ? 1 : 0)
                )
              ],
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _guardarGasto,
              child: Text('GUARDAR GASTO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                minimumSize: Size(double.infinity, 50)
              )
            )
          ],
        ),
      ),
    );
  }
}