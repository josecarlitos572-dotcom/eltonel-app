import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'password_service.dart';

class DatabaseHelper extends ChangeNotifier {
  static Database? _database;
  static const String dbName = 'eltonel_v14.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _loadCache();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(path, version: 16, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE puntos_venta (id INTEGER PRIMARY KEY, nombre TEXT, codigo TEXT UNIQUE, direccion TEXT, dia_descanso TEXT, ini_vta TEXT, fin_vta TEXT, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE categorias_producto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, abreviatura TEXT, orden INTEGER DEFAULT 0, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE categorias_gasto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, limite_max REAL DEFAULT 9999, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT UNIQUE, nombre TEXT, categoria_id INTEGER, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE precios (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, punto_venta_id INTEGER, precio REAL)''');
    await db.execute('''CREATE TABLE personal (id INTEGER PRIMARY KEY AUTOINCREMENT, apellidos TEXT, nombres TEXT, dni TEXT UNIQUE, fono TEXT, rol TEXT, password TEXT, punto_venta_id INTEGER, activo INTEGER DEFAULT 1, requiere_cambio_password INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, dni TEXT, fono TEXT, direccion TEXT, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE inventario (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, punto_venta_id INTEGER, stock INTEGER, fecha TEXT)''');
    await db.execute('''CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER, usuario_id INTEGER, punto_venta_id INTEGER, fecha TEXT, tipo_venta TEXT, monto_total REAL, vuelto REAL, tiene_comprobante INTEGER DEFAULT 0, nombre_cliente TEXT, telefono_cliente TEXT, dni_cliente TEXT, base_imponible REAL DEFAULT 0, igv REAL DEFAULT 0, estado_comanda TEXT DEFAULT 'PENDIENTE', fecha_vencimiento TEXT)''');
    await db.execute('''CREATE TABLE detalle_venta (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER, producto_id INTEGER, cantidad INTEGER, precio_unitario REAL, subtotal REAL)''');
    await db.execute('''CREATE TABLE gastos_internos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, categoria TEXT NOT NULL, descripcion TEXT, monto REAL NOT NULL, tiene_comprobante INTEGER DEFAULT 0, usuario_id INTEGER)''');
    await db.execute('''CREATE TABLE cierres_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, punto_venta_id INTEGER, personal_id INTEGER, saldo_inicial REAL DEFAULT 0, total_ventas REAL DEFAULT 0, total_gastos_manuales REAL DEFAULT 0, saldo_teorico REAL DEFAULT 0, saldo_real_contado REAL DEFAULT 0, diferencia REAL DEFAULT 0, observaciones TEXT)''');
    await db.execute('''CREATE TABLE aperturas_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, punto_venta_id INTEGER, personal_id INTEGER, saldo_inicial REAL DEFAULT 0)''');
    await db.execute('''CREATE TABLE transferencias (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, producto_id INTEGER NOT NULL, cantidad INTEGER NOT NULL, cantidad_recibida INTEGER DEFAULT 0, origen_id INTEGER NOT NULL, destino_id INTEGER NOT NULL, usuario_id INTEGER, tipo TEXT DEFAULT 'TRASLADO', codigo TEXT, estado TEXT DEFAULT 'PENDIENTE')''');
    await db.execute('''CREATE TABLE cuentas_por_cobrar (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER, cliente_id INTEGER, cliente_nombre TEXT, cliente_telefono TEXT, monto_original REAL, monto_pagado REAL DEFAULT 0, saldo_pendiente REAL, fecha_venta TEXT, fecha_vencimiento TEXT, estado TEXT DEFAULT 'PENDIENTE', punto_venta_id INTEGER, observaciones TEXT)''');
    await db.execute('''CREATE TABLE cobros (id INTEGER PRIMARY KEY AUTOINCREMENT, cuenta_id INTEGER, fecha_cobro TEXT, monto_cobrado REAL, tipo_pago TEXT, usuario_id INTEGER, observaciones TEXT)''');
    await db.execute('''CREATE TABLE quiebres (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, hora TEXT, punto_venta_id INTEGER, producto_id INTEGER, tipo TEXT, cantidad_pedida INTEGER, consultado_base INTEGER DEFAULT 0, consultado_otros_puntos INTEGER DEFAULT 0, recuperado_por_traslado INTEGER DEFAULT 0, venta_perdida_estimada REAL DEFAULT 0, usuario_id INTEGER, observaciones TEXT)''');
    await db.execute('''CREATE TABLE batches_generados (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT, origen TEXT, destino TEXT, periodo TEXT, secuencial INTEGER, hash TEXT, hash_anterior TEXT, contenido_json TEXT, fecha_generacion TEXT, estado TEXT DEFAULT 'GENERADO')''');
    await db.execute('''CREATE TABLE batches_recibidos (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT, origen TEXT, destino TEXT, periodo TEXT, secuencial INTEGER, hash TEXT, hash_anterior TEXT, contenido_json TEXT, fecha_generacion TEXT, fecha_recepcion TEXT, estado TEXT DEFAULT 'RECIBIDO')''');
    await db.execute('''CREATE TABLE asignaciones_diarias (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, usuario_id INTEGER, punto_venta_id INTEGER, hora_inicio TEXT, hora_fin TEXT, estado TEXT DEFAULT 'ACTIVO', activado_por INTEGER)''');
    await db.execute('''CREATE TABLE parametros (clave TEXT PRIMARY KEY, valor TEXT, descripcion TEXT)''');
    await db.execute('''CREATE TABLE auditoria_cambios (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, usuario_id INTEGER, usuario_nombre TEXT, tabla_afectada TEXT, accion TEXT, registro_id INTEGER, datos_anteriores TEXT, datos_nuevos TEXT)''');
    await db.execute('''CREATE TABLE batches_serie (serie TEXT PRIMARY KEY, ultimo_correlativo INTEGER DEFAULT 0, ultimo_hash TEXT DEFAULT 'sha256:0000', actualizado_en TEXT)''');
    await _seedSystem(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE personal ADD COLUMN requiere_cambio_password INTEGER DEFAULT 1');
        final users = await db.query('personal');
        for (var user in users) {
          final password = user['password'] as String? ?? '';
          if (password.isNotEmpty && !password.contains(':')) {
            await db.update('personal', {'password': PasswordService.hashPassword(password)}, where: 'id = ?', whereArgs: [user['id']]);
          }
        }
      } catch (e) {}
    }
    if (oldVersion < 16) {
      try {
        await db.execute('''CREATE TABLE batches_serie (serie TEXT PRIMARY KEY, ultimo_correlativo INTEGER DEFAULT 0, ultimo_hash TEXT DEFAULT 'sha256:0000', actualizado_en TEXT)''');
      } catch (e) {}
    }
  }

  Future<void> _seedSystem(Database db) async {
    await db.insert('puntos_venta', {'id': 1, 'nombre': 'LA BASE', 'codigo': 'BASE', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('puntos_venta', {'id': 2, 'nombre': 'Santa Rosa', 'codigo': 'SR1', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('puntos_venta', {'id': 3, 'nombre': 'Víctor Raúl 1', 'codigo': 'VR1', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('puntos_venta', {'id': 4, 'nombre': 'Víctor Raúl 2', 'codigo': 'VR2', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('categorias_gasto', {'nombre': 'SS.HH.', 'limite_max': 2.0});
    await db.insert('categorias_gasto', {'nombre': 'Flete Llegada', 'limite_max': 6});
    await db.insert('categorias_gasto', {'nombre': 'Flete Salida', 'limite_max': 6});
    await db.insert('categorias_gasto', {'nombre': 'Flete Movimiento', 'limite_max': 9});
    await db.insert('categorias_gasto', {'nombre': 'Papel ó Servilleta', 'limite_max': 4});
    await db.insert('categorias_gasto', {'nombre': 'Vasos Plásticos', 'limite_max': 4});
    await db.insert('categorias_gasto', {'nombre': 'Rellenos Panes', 'limite_max': 12});
    await db.insert('categorias_gasto', {'nombre': 'Desayuno', 'limite_max': 6});
    await db.insert('personal', {'apellidos': 'ADMIN', 'nombres': 'PRINCIPAL', 'dni': '09878372', 'rol': 'ADMIN', 'password': PasswordService.hashPassword('JOse\$\$11'), 'punto_venta_id': 1, 'requiere_cambio_password': 1});
    await _seedProductosYCategorias(db);
    await _seedParametros(db);
  }

  Future<void> _seedParametros(Database db) async {
    final params = [
      {'clave': 'empresa_nombre', 'valor': 'Desayunos El Tonel', 'descripcion': 'Nombre de la empresa'},
      {'clave': 'empresa_ruc', 'valor': '', 'descripcion': 'RUC de la empresa'},
      {'clave': 'igv', 'valor': '18', 'descripcion': 'Porcentaje de IGV'},
      {'clave': 'rer', 'valor': '1.5', 'descripcion': 'Porcentaje de RER'},
      {'clave': 'moneda', 'valor': 'S/', 'descripcion': 'Símbolo de moneda'},
      {'clave': 'admin_whatsapp', 'valor': '51999999999', 'descripcion': 'WhatsApp del admin'},
      {'clave': 'hora_cierre', 'valor': '11:00', 'descripcion': 'Hora sugerida de cierre'},
      {'clave': 'inactividad_minutos', 'valor': '5', 'descripcion': 'Minutos para logout'},
      {'clave': 'version_bd', 'valor': '16', 'descripcion': 'Versión actual de la BD'},
    ];
    for (var p in params) { await db.insert('parametros', p, conflictAlgorithm: ConflictAlgorithm.ignore); }
  }

  Future<void> _seedProductosYCategorias(Database db) async {
    final categorias = [
      {'nombre': 'Sándwiches', 'abreviatura': 'SAN', 'orden': 1}, {'nombre': 'Bebidas Calientes', 'abreviatura': 'BEC', 'orden': 2},
      {'nombre': 'Bebidas Frías', 'abreviatura': 'BEF', 'orden': 3}, {'nombre': 'Jugos', 'abreviatura': 'JUG', 'orden': 4},
      {'nombre': 'Ensaladas', 'abreviatura': 'ENS', 'orden': 5}, {'nombre': 'Huevos Sancochados', 'abreviatura': 'HUE', 'orden': 6},
      {'nombre': 'Comidas', 'abreviatura': 'COM', 'orden': 7},
    ];
    for (var cat in categorias) { await db.insert('categorias_producto', cat); }

    final productos = [
      {'codigo': 'A01', 'nombre': 'Pollo Deshilachado', 'cat': 1, 'precio': 2.0}, {'codigo': 'A02', 'nombre': 'Saltado', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A03', 'nombre': 'Huevo Frito', 'cat': 1, 'precio': 2.0}, {'codigo': 'A04', 'nombre': 'Tortilla Hot Dog', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A05', 'nombre': 'Tortilla Papa', 'cat': 1, 'precio': 2.0}, {'codigo': 'A06', 'nombre': 'Tortilla Verduras', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A07', 'nombre': 'Queso', 'cat': 1, 'precio': 2.0}, {'codigo': 'A08', 'nombre': 'Jamón & Queso', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A09', 'nombre': 'Relleno', 'cat': 1, 'precio': 2.0}, {'codigo': 'A10', 'nombre': 'Salchicha Huachana', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A11', 'nombre': 'Pejerrey', 'cat': 1, 'precio': 2.0}, {'codigo': 'A12', 'nombre': 'Camote & Queso', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A13', 'nombre': 'Palta', 'cat': 1, 'precio': 2.0}, {'codigo': 'A14', 'nombre': 'Hamburguesa Carne', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A15', 'nombre': 'Milanesa Pollo', 'cat': 1, 'precio': 2.0}, {'codigo': 'A16', 'nombre': 'Chorizo o Salchicha', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A17', 'nombre': 'Chicharrón', 'cat': 1, 'precio': 4.0}, {'codigo': 'B01', 'nombre': 'Quinua', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B02', 'nombre': 'Maca', 'cat': 2, 'precio': 2.0}, {'codigo': 'B03', 'nombre': '7 Semillas', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B04', 'nombre': 'Avena Manzana', 'cat': 2, 'precio': 2.0}, {'codigo': 'B05', 'nombre': 'Avena Leche', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B06', 'nombre': 'Café', 'cat': 2, 'precio': 2.0}, {'codigo': 'B07', 'nombre': 'Café Leche', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B08', 'nombre': 'Chocolate Leche', 'cat': 2, 'precio': 2.0}, {'codigo': 'C01', 'nombre': 'Chicha', 'cat': 3, 'precio': 2.0},
      {'codigo': 'C02', 'nombre': 'Maracuyá', 'cat': 3, 'precio': 2.0}, {'codigo': 'C03', 'nombre': 'Piña', 'cat': 3, 'precio': 2.0},
      {'codigo': 'D01', 'nombre': 'Fresa Leche', 'cat': 4, 'precio': 3.0}, {'codigo': 'D02', 'nombre': 'Papaya', 'cat': 4, 'precio': 2.0},
      {'codigo': 'D03', 'nombre': 'Mango', 'cat': 4, 'precio': 2.0}, {'codigo': 'E01', 'nombre': 'Ensalada Frutas', 'cat': 5, 'precio': 5.0},
      {'codigo': 'F01', 'nombre': 'Huevo Sancochado', 'cat': 6, 'precio': 1.0}, {'codigo': 'G01', 'nombre': 'Arroz Chaufa / Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G02', 'nombre': 'Arroz Chaufa / Cerdo', 'cat': 7, 'precio': 5.0}, {'codigo': 'G03', 'nombre': 'Arroz Chaufa / Lomito', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G04', 'nombre': 'Arroz Chaufa / Cubana', 'cat': 7, 'precio': 5.0}, {'codigo': 'G05', 'nombre': 'Arroz Cubana', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G06', 'nombre': 'Lomo Saltado', 'cat': 7, 'precio': 5.0}, {'codigo': 'G07', 'nombre': 'Arroz Tapado', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G08', 'nombre': 'Arroz con Pollo', 'cat': 7, 'precio': 5.0}, {'codigo': 'G09', 'nombre': 'Arroz con Pollo / Huancaína', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G10', 'nombre': 'Tallarín Rojo Pollo', 'cat': 7, 'precio': 5.0}, {'codigo': 'G11', 'nombre': 'Tallarín Rojo Pollo / Huancaína', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G12', 'nombre': 'Tallarín Rojo Carne', 'cat': 7, 'precio': 5.0}, {'codigo': 'G13', 'nombre': 'Tallarín Rojo Carne Huancaína', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G14', 'nombre': 'Papa Rellena', 'cat': 7, 'precio': 5.0}, {'codigo': 'G15', 'nombre': 'Escabeche Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G16', 'nombre': 'Escabeche Pescado', 'cat': 7, 'precio': 5.0}, {'codigo': 'G17', 'nombre': 'Estofado Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G18', 'nombre': 'Estofado Carne', 'cat': 7, 'precio': 5.0}, {'codigo': 'G19', 'nombre': 'Picante Carne', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G20', 'nombre': 'Picante Pollo', 'cat': 7, 'precio': 5.0}, {'codigo': 'G21', 'nombre': 'Milanesa Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G22', 'nombre': 'Arroz Jardinera Pollo', 'cat': 7, 'precio': 5.0}, {'codigo': 'G23', 'nombre': 'Arroz Jardinera Cerdo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G24', 'nombre': 'Seco Pollo', 'cat': 7, 'precio': 5.0}, {'codigo': 'G25', 'nombre': 'Caldo Gallina', 'cat': 7, 'precio': 10.0},
      {'codigo': 'G26', 'nombre': 'Patasca', 'cat': 7, 'precio': 15.0},
    ];
    for (var p in productos) {
      int prodId = await db.insert('productos', {'codigo': p['codigo'], 'nombre': p['nombre'], 'categoria_id': p['cat']});
      for (int pvId in [1, 2, 3, 4]) {
        await db.insert('precios', {'producto_id': prodId, 'punto_venta_id': pvId, 'precio': p['precio']});
      }
    }
  }
Future<void> _loadCache() async {}

  // REM: HELPERS BÁSICOS
  Future<int> insertar(String tabla, Map<String, dynamic> datos) async {
    final db = await database;
    return await db.insert(tabla, datos);
  }

  Future<List<Map<String, dynamic>>> consultar(String tabla, {String? where, List<Object?>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(tabla, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? args]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<int> actualizar(String tabla, Map<String, dynamic> datos, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    if (where == null && datos.containsKey('id')) return await db.update(tabla, datos, where: 'id = ?', whereArgs: [datos['id']]);
    return await db.update(tabla, datos, where: where, whereArgs: whereArgs);
  }

  Future<int> eliminar(String tabla, int id) async {
    final db = await database;
    return await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getParametro(String clave) async {
    final db = await database;
    final res = await db.query('parametros', where: 'clave = ?', whereArgs: [clave]);
    return res.isNotEmpty ? res.first['valor'] as String? : null;
  }

  Future<void> setParametro(String clave, String valor, {String? descripcion}) async {
    final db = await database;
    await db.insert('parametros', {'clave': clave, 'valor': valor, 'descripcion': descripcion ?? 'Actualizado desde app'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCategoriasGasto() async {
    final db = await database;
    return await db.query('categorias_gasto', where: 'activo = 1', orderBy: 'id ASC');
  }

  Future<int> reactivarProducto(int id) async {
    final db = await database;
    return await db.update('productos', {'activo': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminarProductoLogico(int id) async {
    final db = await database;
    return await db.update('productos', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPreciosProducto(int productoId) async {
    final db = await database;
    return await db.query('precios', where: 'producto_id = ?', whereArgs: [productoId]);
  }

  Future<void> insertarProductoConPrecios(Map<String, dynamic> producto, List<Map<String, dynamic>> listaPrecios) async {
    final db = await database;
    await db.transaction((txn) async {
      final prodId = await txn.insert('productos', producto);
      for (var precio in listaPrecios) {
        precio['producto_id'] = prodId;
        await txn.insert('precios', precio);
      }
    });
  }

  Future<void> actualizarProductoConPrecios(int productoId, Map<String, dynamic> producto, List<Map<String, dynamic>> listaPrecios) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('productos', producto, where: 'id = ?', whereArgs: [productoId]);
      await txn.delete('precios', where: 'producto_id = ?', whereArgs: [productoId]);
      for (var precio in listaPrecios) {
        precio['producto_id'] = productoId;
        await txn.insert('precios', precio);
      }
    });
  }

  Future<int> registrarGasto(Map<String, dynamic> datosGasto) async {
    final db = await database;
    return await db.insert('gastos_internos', datosGasto);
  }

  Future<List<Map<String, dynamic>>> consultarCuentasPendientes() async {
    final db = await database;
    return await db.query('cuentas_por_cobrar', where: "estado = 'PENDIENTE'", orderBy: 'fecha_vencimiento ASC');
  }

  Future<Map<String, dynamic>> getResumenMensual() async {
    final db = await database;
    final ventas = await db.rawQuery('SELECT SUM(monto_total) AS total FROM ventas');
    final gastos = await db.rawQuery('SELECT SUM(monto) AS total FROM gastos_internos');
    final totalVentas = (ventas.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalGastos = (gastos.first['total'] as num?)?.toDouble() ?? 0.0;
    return {
      'total_ventas': totalVentas,
      'total_gastos': totalGastos,
      'rentabilidad': totalVentas - totalGastos
    };
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final db = await database;
    return await db.rawQuery('SELECT p.*, c.nombre AS categoria_nombre, c.abreviatura AS categoria_abrev FROM productos p LEFT JOIN categorias_producto c ON p.categoria_id = c.id ORDER BY p.codigo ASC');
  }

  Future<List<Map<String, dynamic>>> getCategoriasProducto() async {
    final db = await database;
    return await db.query('categorias_producto', where: 'activo = 1', orderBy: 'orden ASC');
  }

  Future<List<Map<String, dynamic>>> getPuntosVenta() async {
    final db = await database;
    return await db.query('puntos_venta', orderBy: 'id ASC');
  }

  Future<int> registrarClienteSiNoExiste(String nombre, String telefono, String dni) async {
    final db = await database;
    final res = await db.query('clientes', where: 'dni = ? OR fono = ?', whereArgs: [dni, telefono]);
    if (res.isNotEmpty) return res.first['id'] as int;
    return await db.insert('clientes', {'nombre': nombre, 'fono': telefono, 'dni': dni, 'activo': 1});
  }

  Future<void> registrarVenta(Map<String, dynamic> datosVenta, List<Map<String, dynamic>> listaItems, {bool esCredito = false}) async {
    final db = await database;
    double montoTotal = (datosVenta['monto_total'] as num).toDouble();
    datosVenta['base_imponible'] = double.parse((montoTotal / 1.18).toStringAsFixed(2));
    datosVenta['igv'] = double.parse((montoTotal - (montoTotal / 1.18)).toStringAsFixed(2));
    datosVenta['estado_comanda'] = 'PENDIENTE';

    await db.transaction((txn) async {
      final idVenta = await txn.insert('ventas', datosVenta);
      for (var item in listaItems) {
        await txn.insert('detalle_venta', {
          'venta_id': idVenta,
          'producto_id': item['id'],
          'cantidad': item['qty'],
          'precio_unitario': item['price'],
          'subtotal': item['qty'] * item['price']
        });
        final fechaHoy = DateTime.now().toIso8601String().split('T')[0];
        final inv = await txn.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?',
            whereArgs: [item['id'], datosVenta['punto_venta_id'], fechaHoy]);
        if (inv.isEmpty) {
          await txn.insert('inventario', {
            'producto_id': item['id'],
            'punto_venta_id': datosVenta['punto_venta_id'],
            'stock': -(item['qty'] as int),
            'fecha': fechaHoy
          });
        } else {
          final stockActual = (inv.first['stock'] as num).toInt();
          await txn.update('inventario', {'stock': stockActual - (item['qty'] as int)},
              where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?',
              whereArgs: [item['id'], datosVenta['punto_venta_id'], fechaHoy]);
        }
      }
      
      if (esCredito) {
        await txn.insert('cuentas_por_cobrar', {
          'venta_id': idVenta,
          'cliente_id': datosVenta['cliente_id'],
          'cliente_nombre': datosVenta['nombre_cliente'] ?? 'Cliente General',
          'cliente_telefono': datosVenta['telefono_cliente'] ?? '',
          'monto_original': montoTotal,
          'monto_pagado': 0.0,
          'saldo_pendiente': montoTotal,
          'fecha_venta': datosVenta['fecha'],
          'fecha_vencimiento': datosVenta['fecha_vencimiento'] ?? datosVenta['fecha'],
          'estado': 'PENDIENTE',
          'punto_venta_id': datosVenta['punto_venta_id'],
          'observaciones': 'Venta a crédito registrada'
        });
      }
    });
  }

  // REM: LÓGICA DE BATCHES (SIN FILTROS DE ACTIVO PARA PRUEBAS)
  static String calcularHashBatch(Map<String, dynamic> header, List<Map<String, dynamic>> items) {
    final ordenados = items.toList()..sort((a, b) => (a['producto_id'] as int).compareTo(b['producto_id'] as int));
    final canonico = '${header['serie']}|${header['correlativo']}|${header['origen']}|${header['destino']}|${header['tipo']}|${header['hash_anterior']}|' +
        ordenados.map((i) => '${i['producto_id']}:${i['cantidad']}').join('|');
    return 'sha256:${sha256.convert(utf8.encode(canonico)).toString()}';
  }

  Future<Map<String, dynamic>> getSerieInfo(String serie) async {
    final res = await database;
    final r = await res.query('batches_serie', where: 'serie = ?', whereArgs: [serie]);
    if (r.isEmpty) return {'ultimo_correlativo': 0, 'ultimo_hash': 'sha256:0000'};
    final row = Map<String, dynamic>.from(r.first);
    return {
      'ultimo_correlativo': (row['ultimo_correlativo'] as num?)?.toInt() ?? 0,
      'ultimo_hash': row['ultimo_hash'] as String? ?? 'sha256:0000'
    };
  }

  // REM: SIN FILTROS - Consulta el fono del vendedor asignado al PV
  Future<String?> getWhatsappVendedorActivo(int puntoVentaId) async {
    final db = await database;
    final personal = await db.query(
      'personal',
      where: 'punto_venta_id = ? AND rol = ?',
      whereArgs: [puntoVentaId, 'VENDEDOR'],
      limit: 1,
    );
    if (personal.isEmpty) return null;
    return personal.first['fono'] as String?;
  }

  // REM: SIN FILTROS - Genera el batch e incluye la config automáticamente
  Future<String> generarBatchJson({
    required String tipo,
    required String origenCodigo,
    required String destinoCodigo,
    required String dniEmisor,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    final serie = '$origenCodigo-$destinoCodigo';
    final infoSerie = await getSerieInfo(serie);
    final correlativo = infoSerie['ultimo_correlativo'] + 1;
    final hashAnterior = infoSerie['ultimo_hash'];
    final fecha = DateTime.now().toIso8601String();

    final header = {
      'tipo': tipo, 'version': 2, 'serie': serie, 'correlativo': correlativo,
      'origen': origenCodigo, 'destino': destinoCodigo, 'fecha_generacion': fecha,
      'emisor_dni': dniEmisor, 'hash_anterior': hashAnterior
    };

    final payload = <String, dynamic>{'items': items};
    
    // REM: SIN FILTROS - Incluir TODA la config del PV destino
    final pvDestino = await db.query('puntos_venta', where: 'codigo = ?', whereArgs: [destinoCodigo]);
    if (pvDestino.isNotEmpty) {
      final pvId = pvDestino.first['id'] as int;
      
      payload['config'] = {
        'personal': await db.query('personal', where: 'punto_venta_id = ?', whereArgs: [pvId]),
        'productos': await db.query('productos'),
        'precios': await db.query('precios', where: 'punto_venta_id = ?', whereArgs: [pvId]),
        'categorias_producto': await db.query('categorias_producto'),
        'parametros': await db.query('parametros'),
        'puntos_venta': await db.query('puntos_venta'),
      };
    }

    header['hash'] = calcularHashBatch(header, items);
    final jsonFinal = jsonEncode({'header': header, 'payload': payload});

    await db.insert('batches_generados', {
      'tipo': tipo, 'origen': origenCodigo, 'destino': destinoCodigo,
      'periodo': fecha.split('T')[0], 'secuencial': correlativo, 'hash': header['hash'],
      'hash_anterior': hashAnterior, 'contenido_json': jsonFinal,
      'fecha_generacion': fecha, 'estado': 'GENERADO'
    });
    return jsonFinal;
  }
// REM: SIN FILTROS - Valida y registra el batch, procesando la config incluida
  Future<Map<String, dynamic>> validarYRegistrarBatch(String jsonString, int idPuntoVentaUsuario) async {
    final db = await database;
    Map<String, dynamic> data;
    try { 
      data = jsonDecode(jsonString) as Map<String, dynamic>; 
    } catch (e) { 
      return {'ok': false, 'msg': 'Filtro 1: JSON inválido'}; 
    }
    
    final header = data['header'] as Map<String, dynamic>?;
    final payload = data['payload'] as Map<String, dynamic>?;
    if (header == null || payload == null) return {'ok': false, 'msg': 'Filtro 1: Estructura incompleta'};
    if ((header['version'] as num?)?.toInt() != 2) return {'ok': false, 'msg': 'Filtro1: Versión no soportada'};

    final serie = header['serie'] as String? ?? '';
    final origen = header['origen'] as String? ?? '';
    final destino = header['destino'] as String? ?? '';
    final correlativo = (header['correlativo'] as num?)?.toInt() ?? -1;
    final hashRecibido = header['hash'] as String? ?? '';
    final hashAnteriorRecibido = header['hash_anterior'] as String? ?? '';
    final fechaStr = header['fecha_generacion'] as String? ?? '';

    if (serie != '$origen-$destino') return {'ok': false, 'msg': 'Filtro2: Serie no coincide'};
    final pvUsuario = await db.query('puntos_venta', where: 'id = ?', whereArgs: [idPuntoVentaUsuario]);
    if (pvUsuario.isEmpty || (pvUsuario.first['codigo'] as String?) != destino) return {'ok': false, 'msg': 'Filtro3: Destino incorrecto'};
    final pvOrigen = await db.query('puntos_venta', where: 'codigo = ?', whereArgs: [origen]);
    if (pvOrigen.isEmpty) return {'ok': false, 'msg': 'Filtro4: Origen no existe'};

    final fechaParseada = DateTime.tryParse(fechaStr);
    if (fechaParseada == null) return {'ok': false, 'msg': 'Filtro5: Fecha inválida'};
    final ahora = DateTime.now();
    if (fechaParseada.isAfter(ahora.add(const Duration(minutes: 5))) || ahora.difference(fechaParseada).inHours > 48) {
      return {'ok': false, 'msg': 'Filtro5: Fecha fuera de rango'};
    }

    final infoSerie = await getSerieInfo(serie);
    if (correlativo != infoSerie['ultimo_correlativo'] + 1) return {'ok': false, 'msg': 'Filtro6: Correlativo desordenado'};
    if (hashAnteriorRecibido != infoSerie['ultimo_hash']) return {'ok': false, 'msg': 'Filtro7: Hash anterior no coincide'};

    final items = (payload['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final headerParaHash = Map<String, dynamic>.from(header)..remove('hash');
    if (calcularHashBatch(headerParaHash, items) != hashRecibido) return {'ok': false, 'msg': 'Filtro8: Hash de integridad falló'};

    for (var item in items) {
      final prodId = (item['producto_id'] as num?)?.toInt();
      final cantidad = (item['cantidad'] as num?)?.toInt();
      if (prodId == null || cantidad == null || cantidad <= 0) return {'ok': false, 'msg': 'Filtro9: Item inválido'};
      // REM: SIN FILTRO DE ACTIVO PARA PRUEBAS
      final prodExiste = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      if (prodExiste.isEmpty) return {'ok': false, 'msg': 'Filtro9: Producto no existe'};
    }

    final fechaHoy = DateTime.now().toIso8601String().split('T')[0];
    await db.transaction((txn) async {
      for (var item in items) {
        final prodId = (item['producto_id'] as num).toInt();
        final cantidad = (item['cantidad'] as num).toInt();
        final existeInv = await txn.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [prodId, idPuntoVentaUsuario, fechaHoy]);
        if (existeInv.isEmpty) {
          await txn.insert('inventario', {'producto_id': prodId, 'punto_venta_id': idPuntoVentaUsuario, 'stock': cantidad, 'fecha': fechaHoy});
        } else {
          final stockActual = (existeInv.first['stock'] as num).toInt();
          await txn.update('inventario', {'stock': stockActual + cantidad}, where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [prodId, idPuntoVentaUsuario, fechaHoy]);
        }
      }
      await txn.update('batches_serie', {'ultimo_correlativo': correlativo, 'ultimo_hash': hashRecibido, 'actualizado_en': DateTime.now().toIso8601String()}, where: 'serie = ?', whereArgs: [serie]);
      await txn.insert('batches_recibidos', {
        'tipo': header['tipo'], 'origen': origen, 'destino': destino, 'periodo': fechaHoy, 'secuencial': correlativo,
        'hash': hashRecibido, 'hash_anterior': hashAnteriorRecibido, 'contenido_json': jsonString,
        'fecha_generacion': fechaStr, 'fecha_recepcion': DateTime.now().toIso8601String(), 'estado': 'RECIBIDO'
      });

      // REM: SIN FILTROS - Procesar configuración incluida en el batch automáticamente
      final config = payload['config'] as Map<String, dynamic>?;
      if (config != null) {
        if (config['personal'] != null) {
          for (var p in config['personal'] as List) {
            await txn.insert('personal', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (config['productos'] != null) {
          for (var p in config['productos'] as List) {
            await txn.insert('productos', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (config['precios'] != null) {
          for (var p in config['precios'] as List) {
            await txn.insert('precios', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (config['categorias_producto'] != null) {
          for (var c in config['categorias_producto'] as List) {
            await txn.insert('categorias_producto', Map<String, dynamic>.from(c), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (config['parametros'] != null) {
          for (var p in config['parametros'] as List) {
            await txn.insert('parametros', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        if (config['puntos_venta'] != null) {
          for (var p in config['puntos_venta'] as List) {
            await txn.insert('puntos_venta', Map<String, dynamic>.from(p), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });
    return {'ok': true, 'msg': 'Batch $serie #$correlativo registrado, ${items.length} productos, config actualizada'};
  }
}