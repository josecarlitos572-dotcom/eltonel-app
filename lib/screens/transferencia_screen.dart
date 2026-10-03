import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import 'dart:convert'; // REM: Para convertir datos a formato JSON
import 'dart:io'; // REM: Para manejo de archivos del sistema
import 'package:path_provider/path_provider.dart'; // REM: Para obtener rutas de almacenamiento
import 'package:share_plus/share_plus.dart'; // REM: Para compartir archivos con otras apps
import '../services/database_helper.dart'; // REM: Servicio de base de datos
import '../services/auth_service.dart'; // REM: Servicio de autenticación

class TransferenciaScreen extends StatefulWidget { // REM: Pantalla de traslado de stock con estado dinámico
  @override
  _TransferenciaScreenState createState() => _TransferenciaScreenState(); // REM: Crea el estado de la pantalla
}

class _TransferenciaScreenState extends State<TransferenciaScreen> { // REM: Lógica interna de traslados
  List<Map<String, dynamic>> carritoInventario = []; // REM: Lista de productos a trasladar
  int _origenId = 1; // REM: Punto de origen por defecto (Santa Rosa)
  int _destinoId = 2; // REM: Punto de destino por defecto (Víctor Raúl 1)

  final Map<int, String> _puntos = { // REM: Mapa de puntos de venta disponibles
    0: 'LA BASE', 1: 'Santa Rosa (SR1)', 2: 'Víctor Raúl 1 (VR1)', 3: 'Víctor Raúl 2 (VR2)'
  };

  void _agregarAlCarrito(Map<String, dynamic> producto) { // REM: Agrega producto al carrito de traslado
    TextEditingController qtyCtrl = TextEditingController(text: '1'); // REM: Controlador para cantidad
    showDialog( // REM: Muestra diálogo modal
      context: context, // REM: Contexto actual
      builder: (ctx) => AlertDialog( // REM: Diálogo de alerta
        backgroundColor: Colors.grey[900], // REM: Fondo gris oscuro
        title: Text('Cantidad para ${producto['nombre']}', style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Título
        content: TextField( // REM: Campo de entrada
          controller: qtyCtrl, // REM: Controlador
          keyboardType: TextInputType.number, // REM: Teclado numérico
          style: TextStyle(color: Colors.white), // REM: Texto blanco
          decoration: InputDecoration(labelText: 'Unidades', labelStyle: TextStyle(color: Colors.yellow)) // REM: Decoración amarilla
        ),
        actions: [ // REM: Botones de acción
          TextButton( // REM: Botón de confirmar
            onPressed: () {
              int qty = int.tryParse(qtyCtrl.text) ?? 0; // REM: Convierte texto a número
              if (qty > 0) { // REM: Si la cantidad es válida
                setState(() { // REM: Actualiza el estado
                  var existing = carritoInventario.firstWhere((p) => p['id'] == producto['id'], orElse: () => {}); // REM: Busca si ya existe
                  if (existing.isNotEmpty) { existing['qty'] += qty; } // REM: Suma cantidad si existe
                  else { carritoInventario.add({...producto, 'qty': qty}); } // REM: Agrega nuevo si no existe
                });
              }
              Navigator.pop(ctx); // REM: Cierra el diálogo
            },
            child: Text('AGREGAR', style: TextStyle(color: Colors.yellow)), // REM: Texto amarillo
          )
        ],
      ),
    );
  }

  Future<void> _confirmarTraslado() async { // REM: Procesa el traslado de stock
    if (carritoInventario.isEmpty) return; // REM: Si el carrito está vacío, no hace nada
    
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio de autenticación
    final db = await dbHelper.database; // REM: Obtiene instancia de base de datos
    final hoy = DateTime.now().toIso8601String().split('T')[0]; // REM: Fecha actual en formato YYYY-MM-DD
    final userId = auth.currentUser?['id'] ?? 1; // REM: ID del usuario actual

    for (var item in carritoInventario) { // REM: Valida stock disponible en origen
      var stockCheck = await db.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [item['id'], _origenId, hoy]); // REM: Consulta stock
      double disponible = stockCheck.isEmpty ? 0 : (stockCheck.first['stock'] as num).toDouble(); // REM: Obtiene cantidad disponible
      if (disponible < item['qty']) { // REM: Si no hay suficiente stock
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock insuficiente en origen'), backgroundColor: Colors.red)); // REM: Muestra error
        return; // REM: Detiene el proceso
      }
    }

    try { // REM: Intenta procesar el traslado
      await db.transaction((txn) async { // REM: Transacción segura (todo o nada)
        for (var item in carritoInventario) { // REM: Por cada producto
          await txn.rawUpdate('UPDATE inventario SET stock = stock - ? WHERE producto_id = ? AND punto_venta_id = ? AND fecha = ?', [item['qty'], item['id'], _origenId, hoy]); // REM: Resta stock del origen
          
          var stockDest = await txn.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [item['id'], _destinoId, hoy]); // REM: Busca stock en destino
          if (stockDest.isEmpty) { // REM: Si no existe registro en destino
            await txn.insert('inventario', {'producto_id': item['id'], 'punto_venta_id': _destinoId, 'stock': item['qty'], 'fecha': hoy}); // REM: Crea nuevo registro
          } else { // REM: Si ya existe
            await txn.rawUpdate('UPDATE inventario SET stock = stock + ? WHERE id = ?', [item['qty'], stockDest.first['id']]); // REM: Suma al existente
          }

          await txn.insert('transferencias', { // REM: Registra en historial
            'fecha': DateTime.now().toIso8601String(), // REM: Fecha y hora
            'producto_id': item['id'], // REM: ID del producto
            'cantidad': item['qty'], // REM: Cantidad trasladada
            'origen_id': _origenId, // REM: Punto origen
            'destino_id': _destinoId, // REM: Punto destino
            'usuario_id': userId // REM: Usuario que realizó
          });
        }
      });

      final directory = await getApplicationDocumentsDirectory(); // REM: Obtiene carpeta de documentos
      String fileName = 'traslado_${DateTime.now().millisecondsSinceEpoch}.json'; // REM: Nombre único con timestamp
      String filePath = '${directory.path}/$fileName'; // REM: Ruta completa del archivo
      
      Map<String, dynamic> data = { // REM: Datos a exportar
        'tipo': 'TRASLADO_ENTRADA', // REM: Tipo de archivo
        'origen_id': _origenId, // REM: Origen
        'destino_id': _destinoId, // REM: Destino
        'items': carritoInventario.map((e) => {'producto_id': e['id'], 'cantidad': e['qty']}).toList() // REM: Lista de productos
      };

      File file = File(filePath); // REM: Crea objeto archivo
      await file.writeAsString(jsonEncode(data)); // REM: Escribe JSON en el archivo
      
      await Share.shareXFiles([XFile(filePath)], text: 'Traslado de Stock para ${_puntos[_destinoId]}'); // REM: Comparte el archivo
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TRASLADO EXITOSO Y ARCHIVO ENVIADO'), backgroundColor: Colors.green)); // REM: Muestra éxito
      setState(() => carritoInventario.clear()); // REM: Limpia el carrito
    } catch (e) { // REM: Si hay error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red)); // REM: Muestra error
    }
  }

  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual
    final dbHelper = Provider.of<DatabaseHelper>(context); // REM: Obtiene productos
    final auth = Provider.of<AuthService>(context); // REM: Obtiene usuario
    bool isAdmin = auth.currentUser?['rol'] == 'admin'; // REM: Verifica si es admin

    List<MapEntry<int, String>> puntosDisponibles = _puntos.entries.where((e) { // REM: Filtra puntos visibles
      if (isAdmin) return true; // REM: Admin ve todos
      return e.key > 0; // REM: Vendedor solo ve puntos de venta
    }).toList();

    return Scaffold( // REM: Estructura de la pantalla
      appBar: AppBar(title: Text('CARRITO DE TRASLADO'), backgroundColor: Colors.black), // REM: Barra superior
      backgroundColor: Colors.black, // REM: Fondo negro
      body: Column( // REM: Columna vertical
        children: [
          Container( // REM: Selector de ruta
            padding: EdgeInsets.all(10), // REM: Margen interno
            color: Colors.grey[900], // REM: Fondo gris
            child: Row( // REM: Fila horizontal
              children: [
                Expanded( // REM: Origen (ocupa mitad)
                  child: DropdownButton<int>( // REM: Dropdown de selección
                    value: _origenId, // REM: Valor actual
                    dropdownColor: Colors.black, // REM: Color del menú
                    style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew'), // REM: Estilo amarillo
                    items: puntosDisponibles.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), // REM: Opciones
                    onChanged: (val) => setState(() => _origenId = val!), // REM: Cambia valor
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.white), // REM: Flecha indicadora
                Expanded( // REM: Destino (ocupa mitad)
                  child: DropdownButton<int>( // REM: Dropdown de selección
                    value: _destinoId, // REM: Valor actual
                    dropdownColor: Colors.black, // REM: Color del menú
                    style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew'), // REM: Estilo amarillo
                    items: puntosDisponibles.where((e) => e.key != _origenId).map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), // REM: Opciones menos origen
                    onChanged: (val) => setState(() => _destinoId = val!), // REM: Cambia valor
                  ),
                ),
              ],
            ),
          ),
          
          Expanded( // REM: Lista de productos (ocupa espacio restante)
            flex: 2, // REM: Flex 2 para más espacio
            child: ListView.builder( // REM: Lista vertical
              itemCount: dbHelper.products.length, // REM: Cantidad de productos
              itemBuilder: (ctx, i) { // REM: Constructor de ítems
                var prod = dbHelper.products[i]; // REM: Producto actual
                return ListTile( // REM: Ítem de lista
                  title: Text(prod['nombre'], style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')), // REM: Nombre blanco
                  trailing: IconButton( // REM: Botón de agregar
                    icon: Icon(Icons.add_box, color: Colors.yellow), // REM: Ícono caja más amarillo
                    onPressed: () => _agregarAlCarrito(prod) // REM: Agrega al carrito
                  ),
                );
              },
            ),
          ),

          Container( // REM: Resumen del carrito
            height: 150, // REM: Altura fija
            color: Colors.blueGrey[900], // REM: Fondo azul grisáceo
            child: ListView.builder( // REM: Lista interna
              itemCount: carritoInventario.length, // REM: Cantidad de ítems
              itemBuilder: (ctx, i) { // REM: Constructor
                var item = carritoInventario[i]; // REM: Ítem actual
                return ListTile( // REM: Ítem de lista
                  title: Text('${item['nombre']} x${item['qty']}', style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 14)), // REM: Nombre y cantidad
                  trailing: IconButton( // REM: Botón de eliminar
                    icon: Icon(Icons.delete, color: Colors.red), // REM: Ícono basura rojo
                    onPressed: () => setState(() => carritoInventario.removeAt(i)) // REM: Elimina del carrito
                  ),
                );
              },
            ),
          ),

          Padding( // REM: Botón de confirmar
            padding: EdgeInsets.all(15), // REM: Margen
            child: ElevatedButton( // REM: Botón elevado
              onPressed: carritoInventario.isEmpty ? null : _confirmarTraslado, // REM: Activo solo si hay ítems
              child: Text('CONFIRMAR TRASLADO (${carritoInventario.length} ÍTEMS)'), // REM: Texto dinámico
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)), // REM: Ancho completo
            ),
          )
        ],
      ),
    );
  }
}
