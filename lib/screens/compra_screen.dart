import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import '../services/database_helper.dart'; // REM: Servicio de base de datos local
import '../services/auth_service.dart'; // REM: Servicio de autenticación de usuarios

class CompraScreen extends StatefulWidget { // REM: Pantalla de registro de gastos con estado dinámico
  @override
  _CompraScreenState createState() => _CompraScreenState(); // REM: Crea el estado de la pantalla
}

class _CompraScreenState extends State<CompraScreen> { // REM: Lógica interna de registro de gastos
  final TextEditingController _montoCtrl = TextEditingController(); // REM: Controlador para el monto del gasto
  final TextEditingController _descCtrl = TextEditingController(); // REM: Controlador para la descripción del gasto
  int _categoriaId = 1; // REM: ID de la categoría seleccionada por defecto
  List<Map<String, dynamic>> _categorias = []; // REM: Lista de categorías cargadas desde la base de datos
  int tieneComprobante = 0; // REM: Flag binario (1=sí tiene comprobante, 0=no tiene)

  @override
  void initState() { // REM: Se ejecuta al montar la pantalla
    super.initState(); // REM: Llama al initState del padre
    _cargarCategorias(); // REM: Carga las categorías parametrizadas desde la base de datos
  }

  Future<void> _cargarCategorias() async { // REM: Obtiene las categorías de gasto disponibles
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final db = await dbHelper.database; // REM: Obtiene instancia de base de datos
    var cats = await db.query('categorias_gasto', where: 'activo = 1'); // REM: Consulta solo categorías activas
    setState(() { // REM: Actualiza el estado con las categorías
      _categorias = cats; // REM: Guarda la lista de categorías
      if (cats.isNotEmpty) { // REM: Si hay categorías disponibles
        _categoriaId = cats.first['id'] as int; // REM: Casteo explícito a int para evitar error de tipos
      }
    });
  }

  void _guardarGasto() async { // REM: Función para guardar el gasto en la base de datos
    if (_montoCtrl.text.isEmpty) return; // REM: Si el monto está vacío, no hace nada
    
    double monto = double.tryParse(_montoCtrl.text) ?? 0; // REM: Convierte el texto a número decimal
    
    var catSeleccionada = _categorias.firstWhere((c) => c['id'] == _categoriaId); // REM: Busca la categoría seleccionada
    double limite = (catSeleccionada['limite_max'] as num?)?.toDouble() ?? 0.0; // REM: Convierte el límite a double con protección contra null
    
    if (monto > limite) { // REM: Valida que el monto no exceda el límite parametrizado
      ScaffoldMessenger.of(context).showSnackBar( // REM: Muestra mensaje de error
        SnackBar(content: Text('LÍMITE EXCEDIDO. Máximo para ${catSeleccionada['nombre']} es S/. $limite'), backgroundColor: Colors.red) // REM: Texto de error en rojo
      );
      return; // REM: Detiene el proceso sin guardar
    }

    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio de autenticación
    
    String nombreCategoria = catSeleccionada['nombre'] as String; // REM: Casteo explícito a String

    await dbHelper.registrarGasto(nombreCategoria, _descCtrl.text, monto, tieneComprobante); // REM: Guarda el gasto en la base de datos
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gasto Registrado Correctamente'), backgroundColor: Colors.green)); // REM: Muestra mensaje de éxito en verde
    setState(() { _montoCtrl.clear(); _descCtrl.clear(); }); // REM: Limpia los campos de entrada
  }

  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual de la pantalla
    return Scaffold( // REM: Estructura base de la pantalla
      appBar: AppBar(title: Text('REGISTRAR GASTO OPERATIVO'), backgroundColor: Colors.black), // REM: Barra superior con título
      backgroundColor: Colors.black, // REM: Fondo negro absoluto
      body: Padding( // REM: Margen interno
        padding: EdgeInsets.all(20), // REM: 20 píxeles de margen
        child: Column( // REM: Columna vertical de elementos
          children: [
            DropdownButton<int>( // REM: Selector desplegable de categorías
              value: _categoriaId, // REM: Valor actualmente seleccionado
              dropdownColor: Colors.black, // REM: Color de fondo del menú desplegable
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Estilo de texto blanco Courier
              items: _categorias.map<DropdownMenuItem<int>>((val) => DropdownMenuItem<int>( // REM: Tipado explícito del map
                value: val['id'] as int, // REM: Casteo del id a int
                child: Text(val['nombre'] as String), // REM: Casteo del nombre a String
              )).toList(), // REM: Convierte el iterable a lista
              onChanged: (val) => setState(() => _categoriaId = val!), // REM: Actualiza la categoría seleccionada
            ),
            SizedBox(height: 20), // REM: Espacio vertical de 20 píxeles
            TextField( // REM: Campo de descripción del gasto
              controller: _descCtrl, // REM: Vincula el controlador
              decoration: InputDecoration(
                labelText: 'Descripción Detallada', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.white) // REM: Color blanco para la etiqueta
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 20), // REM: Espacio vertical de 20 píxeles
            TextField( // REM: Campo de monto del gasto
              controller: _montoCtrl, // REM: Vincula el controlador
              keyboardType: TextInputType.number, // REM: Muestra teclado numérico
              decoration: InputDecoration(
                labelText: 'Monto S/.', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.white) // REM: Color blanco para la etiqueta
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 20), // REM: Espacio vertical de 20 píxeles
            Row( // REM: Fila horizontal para el switch de comprobante
              mainAxisAlignment: MainAxisAlignment.center, // REM: Centrado horizontal
              children: [
                Text('¿Tiene Comprobante?', style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Texto de la pregunta
                Switch( // REM: Interruptor binario
                  value: tieneComprobante == 1, // REM: Estado actual del switch
                  onChanged: (val) => setState(() => tieneComprobante = val ? 1 : 0) // REM: Cambia entre 1 y 0
                )
              ],
            ),
            SizedBox(height: 30), // REM: Espacio vertical de 30 píxeles
            ElevatedButton( // REM: Botón de acción principal
              onPressed: _guardarGasto, // REM: Ejecuta la función de guardado al presionar
              child: Text('GUARDAR GASTO'), // REM: Texto del botón
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
