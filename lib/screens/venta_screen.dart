import 'package:flutter/material.dart'; // REM: Librería principal de interfaz gráfica
import 'package:provider/provider.dart'; // REM: Gestor de estado para acceder a servicios
import 'package:url_launcher/url_launcher.dart'; // REM: Para abrir WhatsApp
import '../services/database_helper.dart'; // REM: Servicio de base de datos
import '../services/auth_service.dart'; // REM: Servicio de autenticación

class VentaScreen extends StatefulWidget { // REM: Pantalla de ventas con estado dinámico
  @override
  _VentaScreenState createState() => _VentaScreenState(); // REM: Crea el estado de la pantalla
}

class _VentaScreenState extends State<VentaScreen> { // REM: Lógica interna de la pantalla de ventas
  List<Map<String, dynamic>> carrito = []; // REM: Lista temporal de productos agregados
  double total = 0.0; // REM: Suma total del carrito
  String tipoPago = 'contado'; // REM: Método de pago por defecto
  final TextEditingController _nombreClienteCtrl = TextEditingController(); // REM: Campo para nombre en crédito
  int categoriaSeleccionada = 1; // REM: Filtro de categoría actual

  void _agregarAlCarrito(Map<String, dynamic> producto, double precio) { // REM: Agrega producto al carrito
    setState(() { // REM: Actualiza la interfaz
      var existing = carrito.firstWhere((p) => p['id'] == producto['id'], orElse: () => {}); // REM: Busca si ya existe
      if (existing.isNotEmpty) { // REM: Si ya está en el carrito
        existing['qty'] += 1; // REM: Suma una unidad
      } else { // REM: Si es nuevo
        carrito.add({...producto, 'qty': 1, 'price': precio}); // REM: Agrega con cantidad 1 y precio
      }
      _calcularTotal(); // REM: Recalcula el total
    });
  }

  void _calcularTotal() { // REM: Calcula el monto total
    total = carrito.fold(0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['qty'] as num).toInt())); // REM: Suma precio por cantidad
  }

  void _enviarWSP() async { // REM: Envía comanda por WhatsApp
    String texto = "🥐 *DESAYUNOS EL TONEL*\n Pedido:\n"; // REM: Inicio del mensaje
    for (var item in carrito) { // REM: Recorre el carrito
      texto += "• ${item['qty']}x ${item['nombre']} (S/.${item['price']})\n"; // REM: Agrega cada producto
    }
    texto += "\n💰 *Total: S/. ${total.toStringAsFixed(2)}*\nPagado con: ${tipoPago.toUpperCase()}"; // REM: Agrega total y método
    final Uri url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(texto)}"); // REM: Crea enlace de WhatsApp
    if (await canLaunchUrl(url)) { // REM: Verifica si puede abrir
      await launchUrl(url); // REM: Abre WhatsApp
    }
  }

  void _finalizarVenta() async { // REM: Guarda la venta en la base de datos
    if (carrito.isEmpty) return; // REM: Si el carrito está vacío, no hace nada
    
    if (tipoPago == 'credito') { // REM: Si es crédito
      if (_nombreClienteCtrl.text.isEmpty) { // REM: Si no hay nombre
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nombre obligatorio para crédito'), backgroundColor: Colors.red)); // REM: Error
        return; // REM: Detiene el proceso
      }
      if (total > 20) { // REM: Si excede el límite
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Límite de crédito S/. 20 excedido'), backgroundColor: Colors.red)); // REM: Error
        return; // REM: Detiene el proceso
      }
    }

    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false); // REM: Obtiene servicio de base de datos
    final auth = Provider.of<AuthService>(context, listen: false); // REM: Obtiene servicio de autenticación
    
    Map<String, dynamic> ventaData = { // REM: Datos de la venta
      'cliente_id': 1, // REM: ID genérico de cliente
      'usuario_id': auth.currentUser?['id'] ?? 1, // REM: ID del vendedor
      'punto_venta_id': auth.currentUser?['punto_venta_id'] ?? 1, // REM: Punto de venta
      'fecha': DateTime.now().toIso8601String(), // REM: Fecha y hora actual
      'tipo_venta': tipoPago, // REM: Contado o crédito
      'monto_total': total, // REM: Monto total
      'vuelto': 0.0, // REM: Vuelto (por ahora 0)
      'tiene_comprobante': 0, // REM: Sin comprobante fiscal
      if (tipoPago == 'credito') ...{ // REM: Si es crédito
        'nombre_cliente': _nombreClienteCtrl.text, // REM: Nombre del cliente
        'fecha_vencimiento': DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0] // REM: Vence mañana
      }
    };

    try { // REM: Intenta guardar
      await dbHelper.registrarVenta(ventaData, carrito); // REM: Guarda venta y descuenta stock
      
      showDialog( // REM: Muestra diálogo de éxito
        context: context, // REM: Contexto actual
        builder: (ctx) => AlertDialog( // REM: Diálogo de alerta
          backgroundColor: Colors.grey[900], // REM: Fondo gris oscuro
          title: Text('VENTA EXITOSA', style: TextStyle(color: Colors.green)), // REM: Título verde
          actions: [ // REM: Botones de acción
            TextButton(onPressed: () { _enviarWSP(); Navigator.pop(ctx); }, child: Text('ENVIAR WSP', style: TextStyle(color: Colors.yellow))), // REM: Enviar WhatsApp
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CERRAR')), // REM: Cerrar diálogo
          ],
        ),
      );
      
      setState(() { carrito.clear(); total = 0.0; _nombreClienteCtrl.clear(); }); // REM: Limpia el carrito
    } catch (e) { // REM: Si hay error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red)); // REM: Muestra error
    }
  }

  @override
  Widget build(BuildContext context) { // REM: Construye la interfaz visual
    final dbHelper = Provider.of<DatabaseHelper>(context); // REM: Obtiene productos de la base de datos
    var productosFiltrados = dbHelper.products.where((p) => p['categoria_id'] == categoriaSeleccionada).toList(); // REM: Filtra por categoría

    return Scaffold( // REM: Estructura de la pantalla
      appBar: AppBar(title: Text('NUEVA VENTA'), backgroundColor: Colors.black), // REM: Barra superior
      backgroundColor: Colors.black, // REM: Fondo negro
      body: Column( // REM: Columna vertical
        children: [
          Container( // REM: Fila de categorías
            height: 50, // REM: Altura fija
            child: ListView.builder( // REM: Lista horizontal
              scrollDirection: Axis.horizontal, // REM: Dirección horizontal
              itemCount: 7, // REM: 7 categorías
              itemBuilder: (ctx, i) => Padding( // REM: Espaciado
                padding: EdgeInsets.symmetric(horizontal: 5), // REM: Margen horizontal
                child: ElevatedButton( // REM: Botón de categoría
                  onPressed: () => setState(() => categoriaSeleccionada = i + 1), // REM: Cambia categoría seleccionada
                  child: Text('CAT ${i + 1}') // REM: Texto del botón
                )
              )
            )
          ),
          
          Expanded( // REM: Lista de productos (ocupa espacio restante)
            child: ListView.builder( // REM: Lista vertical
              itemCount: productosFiltrados.length, // REM: Cantidad de productos filtrados
              itemBuilder: (ctx, i) { // REM: Constructor de cada ítem
                var prod = productosFiltrados[i]; // REM: Producto actual
                double precioReal = 2.00; // REM: Precio simulado (aquí iría consulta real a tabla precios)
                return ListTile( // REM: Ítem de lista
                  title: Text(prod['nombre'], style: TextStyle(color: Colors.white)), // REM: Nombre del producto
                  trailing: IconButton( // REM: Botón de agregar
                    icon: Icon(Icons.add, color: Colors.yellow), // REM: Ícono más amarillo
                    onPressed: () => _agregarAlCarrito(prod, precioReal) // REM: Agrega al carrito
                  )
                );
              }
            )
          ),

          Container( // REM: Panel inferior de cobro
            color: Colors.grey[900], // REM: Fondo gris oscuro
            padding: EdgeInsets.all(15), // REM: Margen interno
            child: Column( // REM: Columna de controles
              children: [
                if (tipoPago == 'credito') // REM: Solo si es crédito
                  TextField( // REM: Campo de nombre
                    controller: _nombreClienteCtrl, // REM: Controlador
                    decoration: InputDecoration(
                      labelText: 'Nombre Cliente', // REM: Etiqueta
                      labelStyle: TextStyle(color: Colors.yellow) // REM: Color amarillo
                    ),
                    style: TextStyle(color: Colors.white) // REM: Texto blanco
                  ),
                Text( // REM: Mostrar total
                  'TOTAL: S/. ${total.toStringAsFixed(2)}', // REM: Texto del total
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold) // REM: Estilo grande y negrita
                ),
                Row( // REM: Fila de opciones de pago
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // REM: Espaciado equitativo
                  children: [
                    ChoiceChip( // REM: Chip de contado
                      label: Text('CONTADO'), // REM: Texto
                      selected: tipoPago == 'contado', // REM: Seleccionado si es contado
                      onSelected: (val) => setState(() => tipoPago = 'contado'), // REM: Cambia a contado
                      selectedColor: Colors.green, // REM: Color verde cuando seleccionado
                      labelStyle: TextStyle(color: Colors.black) // REM: Texto negro
                    ),
                    ChoiceChip( // REM: Chip de crédito
                      label: Text('CRÉDITO'), // REM: Texto
                      selected: tipoPago == 'credito', // REM: Seleccionado si es crédito
                      onSelected: (val) => setState(() => tipoPago = 'credito'), // REM: Cambia a crédito
                      selectedColor: Colors.orange, // REM: Color naranja cuando seleccionado
                      labelStyle: TextStyle(color: Colors.black) // REM: Texto negro
                    ),
                  ],
                ),
                SizedBox(height: 10), // REM: Espacio vertical
                ElevatedButton( // REM: Botón de confirmar
                  onPressed: _finalizarVenta, // REM: Ejecuta finalizar venta
                  child: Text('CONFIRMAR VENTA'), // REM: Texto del botón
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50), // REM: Ancho completo, alto 50
                    backgroundColor: Colors.yellow, // REM: Fondo amarillo
                    foregroundColor: Colors.black // REM: Texto negro
                  )
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
