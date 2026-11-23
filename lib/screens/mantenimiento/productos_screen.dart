// Archivo: lib/screens/mantenimiento/productos_screen.dart
// Propósito: CRUD de productos con edición de precios por punto de venta.
// CORREGIDO: llamadas a getPreciosProducto, insertarProductoConPrecios y actualizarProductoConPrecios.

import 'package:flutter/material.dart'; // 1. Librería principal de Flutter.
import 'package:provider/provider.dart'; // 2. Para leer el DatabaseHelper desde el árbol de widgets.
import '../../services/database_helper.dart'; // 3. Ruta relativa: subimos un nivel (mantenimiento) y otro (screens) para llegar a services.

class ProductosScreen extends StatefulWidget { // 4. Pantalla con estado (maneja listas y filtros).
  @override
  _ProductosScreenState createState() => _ProductosScreenState(); // 5. Crea el estado asociado.
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Map<String, dynamic>> _productos = []; // 6. Lista de productos leída de la BD.
  List<Map<String, dynamic>> _categorias = []; // 7. Lista de categorías de producto.
  List<Map<String, dynamic>> _puntosVenta = []; // 8. Lista de puntos de venta (para editar precios).
  bool _cargando = true; // 9. Bandera para mostrar el spinner mientras carga.
  String _busqueda = ''; // 10. Texto actual del buscador.
  bool _soloActivos = true; // 11. Filtro para mostrar solo activos o todos.

  @override
  void initState() {
    super.initState(); // 12. Llama al initState del padre.
    _cargarTodo(); // 13. Dispara la carga inicial de datos.
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true); // 14. Activamos el estado de carga.
    final db = Provider.of<DatabaseHelper>(context, listen: false); // 15. Obtenemos el helper sin suscribirnos a cambios.
    final productos = await db.getProductos(); // 16. Trae productos con JOIN de categoría.
    final categorias = await db.getCategoriasProducto(); // 17. Trae categorías activas.
    final puntos = await db.getPuntosVenta(); // 18. Trae todos los puntos de venta.
    setState(() {
      _productos = productos; // 19. Guardamos productos.
      _categorias = categorias; // 20. Guardamos categorías.
      _puntosVenta = puntos.where((p) => p['id'] != 1).toList(); // 21. Excluimos el punto 1 ("LA BASE") de la edición de precios.
      _cargando = false; // 22. Desactivamos el estado de carga.
    });
  }

  List<Map<String, dynamic>> get _filtrados { // 23. Getter que aplica filtros de activo y búsqueda.
    var list = _productos; // 24. Partimos de la lista completa.
    if (_soloActivos) { // 25. Si el filtro de activos está ON.
      list = list.where((p) => (p['activo'] ?? 1) == 1).toList(); // 26. Dejamos solo los con activo == 1.
    }
    if (_busqueda.isEmpty) return list; // 27. Sin texto de búsqueda, devolvemos lo que haya.
    final q = _busqueda.toLowerCase(); // 28. Normalizamos el texto a minúsculas.
    return list.where((p) { // 29. Filtramos por coincidencia en código, nombre o categoría.
      final cod = (p['codigo'] ?? '').toString().toLowerCase(); // 30. Código en minúsculas.
      final nom = (p['nombre'] ?? '').toString().toLowerCase(); // 31. Nombre en minúsculas.
      final cat = (p['categoria_nombre'] ?? '').toString().toLowerCase(); // 32. Categoría en minúsculas.
      return cod.contains(q) || nom.contains(q) || cat.contains(q); // 33. Devolvemos true si coincide en alguno.
    }).toList();
  }

  Future<void> _cambiarEstado(int id, String nombre, bool activar) async { // 34. Cambia activo/inactivo con confirmación.
    final accion = activar ? 'reactivar' : 'desactivar'; // 35. Texto de la acción para el diálogo.
    final conf = await showDialog<bool>( // 36. Muestra un AlertDialog de confirmación.
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black, // 37. Fondo negro del diálogo.
        title: Text('¿${accion.toUpperCase()}?', // 38. Título en mayúsculas.
            style: TextStyle(color: activar ? Colors.green : Colors.red, fontFamily: 'CourierNew')),
        content: Text('Se va a $accion "$nombre"', // 39. Cuerpo con el nombre del producto.
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), // 40. Cancelar devuelve false.
              child: Text('NO', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(context, true), // 41. Confirmar devuelve true.
              child: Text('SÍ', style: TextStyle(color: activar ? Colors.green : Colors.red))),
        ],
      ),
    );
    if (conf == true) { // 42. Solo actuamos si el usuario confirmó.
      final db = Provider.of<DatabaseHelper>(context, listen: false); // 43. Obtenemos el helper.
      if (activar) { // 44. Si es reactivación.
        await db.reactivarProducto(id); // 45. Llama a reactivarProducto (activo = 1).
      } else { // 46. Si es desactivación.
        await db.eliminarProductoLogico(id); // 47. Llama a eliminarProductoLogico (activo = 0).
      }
      _cargarTodo(); // 48. Recargamos la lista para reflejar el cambio.
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? producto}) async { // 49. Abre el diálogo de crear/editar.
    final codigoCtrl = TextEditingController(text: producto?['codigo'] ?? ''); // 50. Controlador del código.
    final nombreCtrl = TextEditingController(text: producto?['nombre'] ?? ''); // 51. Controlador del nombre.
    int? categoriaId = producto?['categoria_id'] as int?; // 52. Categoría actual (o null si es nuevo).
    if (categoriaId == null && _categorias.isNotEmpty) { // 53. Si no hay categoría y existen, usamos la primera.
      categoriaId = _categorias.first['id'] as int;
    }

    final Map<int, TextEditingController> preciosCtrl = {}; // 54. Mapa punto_venta_id -> controlador de precio.
    if (producto != null) { // 55. Modo edición: cargamos los precios actuales.
      // 56. ¡CORREGIDO! El método se llama getPreciosProducto (no getPreciosDeProducto).
      final precios = await Provider.of<DatabaseHelper>(context, listen: false)
          .getPreciosProducto(producto['id'] as int);
      for (var pv in _puntosVenta) { // 57. Para cada punto de venta editable.
        final match = precios.firstWhere( // 58. Buscamos el precio de ese punto.
          (p) => p['punto_venta_id'] == pv['id'],
          orElse: () => {'precio': 0.0}, // 59. Si no existe, usamos 0.0.
        );
        preciosCtrl[pv['id'] as int] = TextEditingController( // 60. Creamos el controlador con el precio actual.
          text: (match['precio'] ?? 0.0).toString(),
        );
      }
    } else { // 61. Modo nuevo: todos los precios en 0.0.
      for (var pv in _puntosVenta) {
        preciosCtrl[pv['id'] as int] = TextEditingController(text: '0.0');
      }
    }

    if (!mounted) return; // 62. Guardamos el estado si el widget sigue montado.

    final guardar = await showDialog<bool>( // 63. Mostramos el formulario como diálogo.
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black, // 64. Fondo negro.
        title: Text( // 65. Título según modo.
          producto == null ? 'NUEVO PRODUCTO' : 'EDITAR PRODUCTO',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
        content: SingleChildScrollView( // 66. Scroll para que no desborde en pantallas pequeñas.
          child: Column(
            mainAxisSize: MainAxisSize.min, // 67. Columna lo más compacta posible.
            children: [
              TextField( // 68. Campo de código.
                controller: codigoCtrl,
                decoration: InputDecoration(labelText: 'Código (ej: A01)'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10), // 69. Separador.
              TextField( // 70. Campo de nombre.
                controller: nombreCtrl,
                decoration: InputDecoration(labelText: 'Nombre'),
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              ),
              SizedBox(height: 10), // 71. Separador.
              DropdownButtonFormField<int>( // 72. Selector de categoría.
                value: categoriaId,
                dropdownColor: Colors.black, // 73. Fondo negro del dropdown.
                style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                decoration: InputDecoration(labelText: 'Categoría'),
                items: _categorias.map<DropdownMenuItem<int>>((c) { // 74. Construimos los items.
                  return DropdownMenuItem<int>(
                    value: c['id'] as int, // 75. Valor = id de categoría.
                    child: Text( // 76. Texto = abreviatura + nombre.
                      '${c['abreviatura'] ?? ''} - ${c['nombre']}',
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (v) => categoriaId = v, // 77. Actualizamos la categoría seleccionada.
              ),
              SizedBox(height: 15), // 78. Separador.
              Text('PRECIOS POR PUNTO DE VENTA', // 79. Subtítulo de la sección de precios.
                  style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 11)),
              SizedBox(height: 10), // 80. Separador.
              ..._puntosVenta.map((pv) { // 81. Un TextField por cada punto de venta.
                final id = pv['id'] as int; // 82. ID del punto de venta.
                return Padding( // 83. Padding vertical para separar los campos.
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: preciosCtrl[id], // 84. Controlador asociado a este punto.
                    keyboardType: TextInputType.number, // 85. Teclado numérico.
                    decoration: InputDecoration(
                      labelText: '${pv['codigo']} - ${pv['nombre']}', // 86. Etiqueta con código y nombre del PV.
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), // 87. Cancelar.
              child: Text('CANCELAR', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), // 88. Guardar.
              child: Text('GUARDAR', style: TextStyle(color: Colors.yellow))),
        ],
      ),
    );

    if (guardar == true) { // 89. Solo guardamos si el usuario pulsó GUARDAR.
      if (codigoCtrl.text.trim().isEmpty || nombreCtrl.text.trim().isEmpty) { // 90. Validación de campos obligatorios.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete código y nombre'), backgroundColor: Colors.red),
        );
        return; // 91. Salimos sin guardar.
      }
      final Map<int, double> precios = {}; // 92. Mapa pvId -> monto final.
      for (var entry in preciosCtrl.entries) { // 93. Convertimos los textos a double.
        precios[entry.key] = double.tryParse(entry.value.text) ?? 0.0;
      }

      // 94. ¡CORREGIDO! Construimos el Map del producto con las claves que espera el helper.
      final Map<String, dynamic> productoMap = {
        'codigo': codigoCtrl.text.trim(), // 95. Clave 'codigo' (la tabla productos usa 'codigo').
        'nombre': nombreCtrl.text.trim(), // 96. Clave 'nombre'.
        'categoria_id': categoriaId, // 97. Clave 'categoria_id'.
        'activo': 1, // 98. Siempre activo al guardar desde aquí.
      };
      // 99. ¡CORREGIDO! Construimos la List<Map> de precios con las claves que espera el helper.
      final List<Map<String, dynamic>> listaPrecios = [
        for (var e in precios.entries)
          {'punto_venta_id': e.key, 'precio': e.value}, // 100. Cada item: pv_id + precio.
      ];

      final db = Provider.of<DatabaseHelper>(context, listen: false); // 101. Obtenemos el helper.
      try {
        if (producto == null) { // 102. Modo NUEVO.
          // 103. ¡CORREGIDO! insertarProductoConPrecios(productoMap, listaPrecios) -> 2 args posicionales.
          await db.insertarProductoConPrecios(productoMap, listaPrecios);
        } else { // 104. Modo EDICIÓN.
          // 105. ¡CORREGIDO! actualizarProductoConPrecios(id, productoMap, listaPrecios) -> 3 args posicionales.
          await db.actualizarProductoConPrecios(
            producto['id'] as int, // 106. Primer arg: id del producto.
            productoMap, // 107. Segundo arg: Map con los datos del producto.
            listaPrecios, // 108. Tercer arg: List con los precios por PV.
          );
        }
        _cargarTodo(); // 109. Recargamos la lista para ver los cambios.
        ScaffoldMessenger.of(context).showSnackBar( // 110. Confirmación en verde.
          SnackBar(content: Text('Producto guardado correctamente'), backgroundColor: Colors.green),
        );
      } catch (e) { // 111. Capturamos errores (por ejemplo, código duplicado UNIQUE).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) { // 112. Método que construye la interfaz.
    final filtrados = _filtrados; // 113. Aplicamos los filtros del getter.
    return Scaffold(
      appBar: AppBar( // 114. Barra superior.
        title: Text('PRODUCTOS (${filtrados.length})'), // 115. Título con contador.
        actions: [
          IconButton( // 116. Botón para alternar filtro de activos.
            icon: Icon(_soloActivos ? Icons.visibility : Icons.visibility_off, color: Colors.yellow),
            tooltip: _soloActivos ? 'Mostrando solo activos' : 'Mostrando todos',
            onPressed: () => setState(() => _soloActivos = !_soloActivos), // 117. Invertimos el filtro.
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarTodo), // 118. Botón de recarga manual.
        ],
      ),
      backgroundColor: Colors.black, // 119. Fondo negro de la pantalla.
      floatingActionButton: FloatingActionButton( // 120. Botón flotante para crear producto.
        backgroundColor: Colors.yellow,
        onPressed: () => _abrirFormulario(), // 121. Abre el formulario en modo nuevo.
        child: Icon(Icons.add, color: Colors.black),
      ),
      body: Column( // 122. Cuerpo con buscador arriba y lista abajo.
        children: [
          Padding( // 123. Padding del buscador.
            padding: EdgeInsets.all(10),
            child: TextField( // 124. Campo de búsqueda.
              onChanged: (v) => setState(() => _busqueda = v), // 125. Actualiza el texto de búsqueda.
              decoration: InputDecoration(
                hintText: 'Buscar por código, nombre o categoría...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: Colors.yellow),
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13),
            ),
          ),
          Expanded( // 126. Lista que ocupa el espacio restante.
            child: _cargando // 127. Si está cargando, spinner.
                ? Center(child: CircularProgressIndicator(color: Colors.yellow))
                : filtrados.isEmpty // 128. Si no hay resultados, mensaje.
                    ? Center(
                        child: Text('Sin productos',
                            style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew')),
                      )
                    : ListView.builder( // 129. Si hay resultados, lista.
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) { // 130. Construimos cada ListTile.
                          final p = filtrados[i]; // 131. Producto actual.
                          final activo = (p['activo'] ?? 1) == 1; // 132. Estado activo/inactivo.
                          return ListTile(
                            leading: CircleAvatar( // 133. Avatar con el código.
                              backgroundColor: activo ? Colors.yellow : Colors.grey,
                              child: Text(
                                p['codigo'] ?? '?',
                                style: TextStyle(
                                    color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text( // 134. Nombre del producto.
                              p['nombre'] ?? '',
                              style: TextStyle(
                                color: activo ? Colors.white : Colors.white38,
                                fontFamily: 'CourierNew',
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text( // 135. Subtítulo con categoría y estado.
                              '${p['categoria_abrev'] ?? ''} - ${p['categoria_nombre'] ?? ''} ${activo ? "" : "(INACTIVO)"}',
                              style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11),
                            ),
                            trailing: Row( // 136. Acciones a la derecha (editar / activar-desactivar).
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton( // 137. Botón editar.
                                  icon: Icon(Icons.edit, color: Colors.yellow, size: 20),
                                  onPressed: () => _abrirFormulario(producto: p), // 138. Abre el formulario en modo edición.
                                ),
                                IconButton( // 139. Botón activar/desactivar.
                                  icon: Icon(activo ? Icons.delete : Icons.restore,
                                      color: activo ? Colors.red : Colors.green, size: 20),
                                  onPressed: () => _cambiarEstado(
                                      p['id'] as int, p['nombre'] ?? '', !activo), // 140. Cambia al estado opuesto.
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ); // 141. Cierre del Scaffold.
  } // 142. Cierre del build.
} // 143. Cierre de la clase _ProductosScreenState.