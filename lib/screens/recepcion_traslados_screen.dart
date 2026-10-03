import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import 'package:file_picker/file_picker.dart'; // REM: Librería para seleccionar archivos del dispositivo
import 'dart:convert'; // REM: Librería para decodificar texto formato JSON
import 'dart:io'; // REM: Librería para manejo de archivos del sistema operativo
import '../services/database_helper.dart'; // REM: Servicio de base de datos local
import '../services/auth_service.dart'; // REM: Servicio de autenticación de usuarios

class RecepcionTrasladosScreen extends StatefulWidget { // REM: Pantalla de recepción con estado dinámico
  @override
  _RecepcionTrasladosScreenState createState() => _RecepcionTrasladosScreenState(); // REM: Crea el estado de la pantalla
}

class _RecepcionTrasladosScreenState extends State<RecepcionTrasladosScreen> { // REM: Lógica interna de recepción
  final TextEditingController _saldoInicialCtrl = TextEditingController(); // REM: Controlador para el monto de cambio inicial en efectivo

  Future<void> _procesarArchivo() async { // REM: Función asíncrona para leer y procesar el JSON recibido
    try { // REM: Bloque de intento para capturar posibles errores
      FilePickerResult? result = await FilePicker.platform.pickFiles( // REM: Abre el selector de archivos del celular
        type: FileType.custom, // REM: Tipo de archivo personalizado
        allowedExtensions: ['json'], // REM: Solo permite seleccionar archivos con extensión .json
      );

      if (result != null) { // REM: Si el usuario seleccionó un archivo válidamente
        String content = await File(result.files.single.path!).readAsString(); // REM: Lee el contenido del archivo como texto
        Map<String, dynamic> data = jsonDecode(content); // REM: Convierte el texto JSON en un objeto de datos de Dart

        if (data['tipo'] != 'TRASLADO_ENTRADA') { // REM: Valida que el archivo sea del tipo correcto
          throw Exception('Archivo no válido para recepción'); // REM: Lanza error si no coincide el tipo
        }

        final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene el servicio de base de datos
        final db = await dbHelper.database; // REM: Obtiene la instancia de la base de datos
        final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene el servicio de autenticación
        final hoy = DateTime.now().toIso8601String().split('T')[0]; // REM: Obtiene la fecha de hoy en formato YYYY-MM-DD
        final myPvId = auth.currentUser?['punto_venta_id']; // REM: Obtiene el ID del punto de venta del usuario actual

        if (data['destino_id'] != myPvId) { // REM: Valida que el traslado esté dirigido a este punto de venta específico
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Este traslado no es para tu punto de venta'), backgroundColor: Colors.red)); // REM: Muestra mensaje de error en rojo
           return; // REM: Detiene la ejecución de la función
        }

        await db.transaction((txn) async { // REM: Inicia una transacción de base de datos segura (todo o nada)
          for (var item in data['items']) { // REM: Itera sobre cada producto listado en el archivo JSON
            int prodId = item['producto_id']; // REM: Extrae el ID del producto
            int qty = item['cantidad']; // REM: Extrae la cantidad a recibir

            var existing = await txn.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [prodId, myPvId, hoy]); // REM: Busca si ya existe registro de inventario para hoy

            if (existing.isEmpty) { // REM: Si no existe registro previo para este producto hoy
              await txn.insert('inventario', {'producto_id': prodId, 'punto_venta_id': myPvId, 'stock': qty, 'fecha': hoy}); // REM: Crea un nuevo registro con la cantidad recibida
            } else { // REM: Si ya existe un registro de inventario para hoy
              await txn.rawUpdate('UPDATE inventario SET stock = stock + ? WHERE id = ?', [qty, existing.first['id']]); // REM: Suma la cantidad recibida al stock existente
            }
          }
        });

        double saldo = double.tryParse(_saldoInicialCtrl.text) ?? 0; // REM: Intenta convertir el texto del campo a número decimal, o 0 si falla
        if (saldo > 0) { // REM: Si el monto de cambio inicial es mayor a cero
           await db.insert('aperturas_caja', { // REM: Registra la apertura de caja en la base de datos
             'fecha': hoy, // REM: Fecha de la apertura
             'punto_venta_id': myPvId, // REM: ID del punto de venta
             'personal_id': auth.currentUser?['id'], // REM: ID del personal que recibe
             'saldo_inicial': saldo // REM: Monto del cambio inicial registrado
           });
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('STOCK ACTUALIZADO Y JORNADA INICIADA'), backgroundColor: Colors.green)); // REM: Muestra mensaje de éxito en verde
      }
    } catch (e) { // REM: Bloque de captura de errores
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.red)); // REM: Muestra el error técnico en pantalla
    }
  }

  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual de la pantalla
    return Scaffold( // REM: Estructura base de la pantalla
      appBar: AppBar(title: Text('RECEPCIÓN DE TRASLADOS'), backgroundColor: Colors.black), // REM: Barra superior con título
      backgroundColor: Colors.black, // REM: Fondo negro absoluto
      body: Center( // REM: Centra el contenido en la pantalla
        child: Column( // REM: Organiza los elementos en columna vertical
          mainAxisAlignment: MainAxisAlignment.center, // REM: Centra verticalmente
          children: [
            Icon(Icons.upload_file, size: 80, color: Colors.yellow), // REM: Ícono grande de carga de archivo en amarillo
            SizedBox(height: 20), // REM: Espacio vertical de 20 píxeles
            Text( // REM: Texto de instrucción para el usuario
              'SELECCIONA EL ARCHIVO .JSON\nENVIADO POR EL ORIGEN', 
              textAlign: TextAlign.center, // REM: Alineación centrada
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew') // REM: Estilo de texto blanco Courier
            ),
            SizedBox(height: 20), // REM: Espacio vertical de 20 píxeles
            TextField( // REM: Campo de entrada para el saldo inicial
              controller: _saldoInicialCtrl, // REM: Vincula el controlador
              keyboardType: TextInputType.number, // REM: Muestra teclado numérico
              decoration: InputDecoration(
                labelText: 'Monto de Cambio (S/.)', // REM: Etiqueta flotante
                labelStyle: TextStyle(color: Colors.yellow), // REM: Color amarillo para la etiqueta
                border: OutlineInputBorder() // REM: Borde rectangular
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'), // REM: Texto ingresado en blanco Courier
            ),
            SizedBox(height: 30), // REM: Espacio vertical de 30 píxeles
            ElevatedButton( // REM: Botón de acción principal
              onPressed: _procesarArchivo, // REM: Ejecuta la función de procesamiento al presionar
              child: Text('CARGAR Y ACTUALIZAR STOCK'), // REM: Texto del botón
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow, // REM
