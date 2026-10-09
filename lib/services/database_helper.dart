import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper extends ChangeNotifier {
  static Database? _database;
  List<Map<String, dynamic>> _cachedProducts = [];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _loadCache();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'eltonel.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE puntos_venta (id INTEGER PRIMARY KEY, nombre TEXT, codigo TEXT UNIQUE, direccion TEXT, dia_descanso TEXT, ini_vta TEXT, fin_vta TEXT, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE categorias_producto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, abreviatura TEXT, orden INTEGER DEFAULT 0, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE categorias_gasto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, limite_max REAL DEFAULT 9999, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT UNIQUE, nombre TEXT, categoria_id INTEGER, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE precios (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, punto_venta_id INTEGER, precio REAL)''');
    await db.execute('''CREATE TABLE personal (id INTEGER PRIMARY KEY AUTOINCREMENT, apellidos TEXT, nombres TEXT, dni TEXT UNIQUE, fono TEXT, rol TEXT, password TEXT, punto_venta_id INTEGER, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, dni TEXT, fono TEXT, direccion TEXT, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE inventario (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, punto_venta_id INTEGER, stock INTEGER, fecha TEXT)''');
    await db.execute('''CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER, usuario_id INTEGER, punto_venta_id INTEGER, fecha TEXT, tipo_venta TEXT, monto_total REAL, vuelto REAL, tiene_comprobante INTEGER DEFAULT 0, nombre_cliente TEXT, fecha_vencimiento TEXT)''');
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
    await _seedSystem(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 10) {
      await db.update('categorias_gasto', {'limite_max': 2.0},
          where: 'nombre = ?', whereArgs: ['SS.HH.']);
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE puntos_venta ADD COLUMN dia_descanso TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE puntos_venta ADD COLUMN ini_vta TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE puntos_venta ADD COLUMN fin_vta TEXT');
      } catch (e) {}
      await db.update('puntos_venta',
          {'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE transferencias ADD COLUMN cantidad_recibida INTEGER DEFAULT 0');
      } catch (e) {}
      try {
        await db.execute("ALTER TABLE transferencias ADD COLUMN tipo TEXT DEFAULT 'TRASLADO'");
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE transferencias ADD COLUMN codigo TEXT');
      } catch (e) {}
      try {
        await db.execute("ALTER TABLE transferencias ADD COLUMN estado TEXT DEFAULT 'PENDIENTE'");
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

    await db.insert('personal', {
      'apellidos': 'Dueño', 'nombres': 'Admin', 'dni': '00000000',
      'rol': 'ADMIN', 'password': 'tonel123', 'punto_venta_id': 0
    });

    await _seedProductosYCategorias(db);
    await _seedParametros(db);
  }

  Future<void> _seedParametros(Database db) async {
    final params = [
      {'clave': 'empresa_nombre', 'valor': 'Desayunos El Tonel', 'descripcion': 'Nombre de la empresa'},
      {'clave': 'empresa_ruc', 'valor': '', 'descripcion': 'RUC de la empresa'},
      {'clave': 'igv', 'valor': '18', 'descripcion': 'Porcentaje de IGV'},
      {'clave': 'moneda', 'valor': 'S/', 'descripcion': 'Símbolo de moneda'},
      {'clave': 'admin_whatsapp', 'valor': '51999999999', 'descripcion': 'WhatsApp del admin'},
      {'clave': 'hora_cierre', 'valor': '11:00', 'descripcion': 'Hora sugerida de cierre'},
      {'clave': 'inactividad_minutos', 'valor': '5', 'descripcion': 'Minutos para logout'},
      {'clave': 'version_bd', 'valor': '12', 'descripcion': 'Versión actual de la BD'},
    ];
    for (var p in params) {
      await db.insert('parametros', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedProductosYCategorias(Database db) async {
    final categorias = [
      {'nombre': 'Sándwiches', 'abreviatura': 'SAN', 'orden': 1},
      {'nombre': 'Bebidas Calientes', 'abreviatura': 'BEC', 'orden': 2},
      {'nombre': 'Bebidas Frías', 'abreviatura': 'BEF', 'orden': 3},
      {'nombre': 'Jugos', 'abreviatura': 'JUG', 'orden': 4},
      {'nombre': 'Ensaladas', 'abreviatura': 'ENS', 'orden': 5},
      {'nombre': 'Huevos Sancochados', 'abreviatura': 'HUE', 'orden': 6},
      {'nombre': 'Comidas', 'abreviatura': 'COM', 'orden': 7},
    ];
    for (var cat in categorias) {
      await db.insert('categorias_producto', cat);
    }

    final productos = [
      {'codigo': 'A01', 'nombre': 'Pollo Deshilachado', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A02', 'nombre': 'Saltado', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A03', 'nombre': 'Huevo Frito', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A04', 'nombre': 'Tortilla Hot Dog', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A05', 'nombre': 'Tortilla Papa', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A06', 'nombre': 'Tortilla Verduras', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A07', 'nombre': 'Queso', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A08', 'nombre': 'Jamón & Queso', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A09', 'nombre': 'Relleno', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A10', 'nombre': 'Salchicha Huachana', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A11', 'nombre': 'Pejerrey', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A12', 'nombre': 'Camote & Queso', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A13', 'nombre': 'Palta', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A14', 'nombre': 'Hamburguesa Carne', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A15', 'nombre': 'Milanesa Pollo', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A16', 'nombre': 'Chorizo o Salchicha', 'cat': 1, 'precio': 2.0},
      {'codigo': 'A17', 'nombre': 'Chicharrón', 'cat': 1, 'precio': 4.0},
      {'codigo': 'B01', 'nombre': 'Quinua', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B02', 'nombre': 'Maca', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B03', 'nombre': '7 Semillas', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B04', 'nombre': 'Avena Manzana', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B05', 'nombre': 'Avena Leche', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B06', 'nombre': 'Café', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B07', 'nombre': 'Café Leche', 'cat': 2, 'precio': 2.0},
      {'codigo': 'B08', 'nombre': 'Chocolate Leche', 'cat': 2, 'precio': 2.0},
      {'codigo': 'C01', 'nombre': 'Chicha', 'cat': 3, 'precio': 2.0},
      {'codigo': 'C02', 'nombre': 'Maracuyá', 'cat': 3, 'precio': 2.0},
      {'codigo': 'C03', 'nombre': 'Piña', 'cat': 3, 'precio': 2.0},
      {'codigo': 'D01', 'nombre': 'Fresa Leche', 'cat': 4, 'precio': 3.0},
      {'codigo': 'D02', 'nombre': 'Papaya', 'cat': 4, 'precio': 2.0},
      {'codigo': 'D03', 'nombre': 'Mango', 'cat': 4, 'precio': 2.0},
      {'codigo': 'E01', 'nombre': 'Ensalada Frutas', 'cat': 5, 'precio': 5.0},
      {'codigo': 'F01', 'nombre': 'Huevo Sancochado', 'cat': 6, 'precio': 1.0},
      {'codigo': 'G01', 'nombre': 'Arroz Chaufa / Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G02', 'nombre': 'Arroz Chaufa / Cerdo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G03', 'nombre': 'Arroz Chaufa / Lomito', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G04', 'nombre': 'Arroz Chaufa / Cubana', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G05', 'nombre': 'Arroz Cubana', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G06', 'nombre': 'Lomo Saltado', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G07', 'nombre': 'Arroz Tapado', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G08', 'nombre': 'Arroz con Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G09', 'nombre': 'Arroz con Pollo / Huancaína', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G10', 'nombre': 'Tallarín Rojo Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G11', 'nombre': 'Tallarín Rojo Pollo / Huancaína', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G12', 'nombre': 'Tallarín Rojo Carne', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G13', 'nombre': 'Tallarín Rojo Carne Huancaína', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G14', 'nombre': 'Papa Rellena', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G15', 'nombre': 'Escabeche Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G16', 'nombre': 'Escabeche Pescado', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G17', 'nombre': 'Estofado Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G18', 'nombre': 'Estofado Carne', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G19', 'nombre': 'Picante Carne', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G20', 'nombre': 'Picante Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G21', 'nombre': 'Milanesa Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G22', 'nombre': 'Arroz Jardinera Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G23', 'nombre': 'Arroz Jardinera Cerdo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G24', 'nombre': 'Seco Pollo', 'cat': 7, 'precio': 5.0},
      {'codigo': 'G25', 'nombre': 'Caldo Gallina', 'cat': 7, 'precio': 10.0},
      {'codigo': 'G26', 'nombre': 'Patasca', 'cat': 7, 'precio': 15.0},
    ];

    for (var p in productos) {
      int prodId = await db.insert('productos', {
        'codigo': p['codigo'],
        'nombre': p['nombre'],
        'categoria_id': p['cat'],
      });
      for (int pvId in [2, 3, 4]) {
        await db.insert('precios', {
          'producto_id': prodId,
          'punto_venta_id': pvId,
          'precio': p['precio'],
        });
      }
    }
  }

  Future<int> insertar(String tabla, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(tabla, data);
  }

  Future<int> actualizar(String tabla, Map<String, dynamic> data) async {
    final db = await database;
    final id = data['id'];
    return await db.update(tabla, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminar(String tabla, int id) async {
    final db = await database;
    return await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> consultar(
    String tabla, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return await db.query(tabla, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.nombre as categoria_nombre, c.abreviatura as categoria_abrev
      FROM productos p
      LEFT JOIN categorias_producto c ON p.categoria_id = c.id
      ORDER BY p.codigo ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCategoriasProducto() async {
    final db = await database;
    return await db.query('categorias_producto', where: 'activo = 1', orderBy: 'orden ASC, id ASC');
  }

  Future<List<Map<String, dynamic>>> getPuntosVenta() async {
    final db = await database;
    return await db.query('puntos_venta', orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getCategoriasGasto() async {
    final db = await database;
    return await db.query('categorias_gasto', where: 'activo = 1', orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>?> getProductoPorId(int id) async {
    final db = await database;
    final r = await db.rawQuery('''
      SELECT p.*, c.nombre as categoria_nombre, c.abreviatura as categoria_abrev
      FROM productos p
      LEFT JOIN categorias_producto c ON p.categoria_id = c.id
      WHERE p.id = ?
    ''', [id]);
    if (r.isEmpty) return null;
    return r.first;
  }

  Future<List<Map<String, dynamic>>> getPreciosDeProducto(int productoId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pr.*, pv.nombre as punto_nombre, pv.codigo as punto_codigo
      FROM precios pr
      LEFT JOIN puntos_venta pv ON pr.punto_venta_id = pv.id
      WHERE pr.producto_id = ?
      ORDER BY pr.punto_venta_id ASC
    ''', [productoId]);
  }

  Future<int> insertarProductoConPrecios({
    required String codigo,
    required String nombre,
    required int categoriaId,
    required Map<int, double> precios,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      int prodId = await txn.insert('productos', {
        'codigo': codigo, 'nombre': nombre, 'categoria_id': categoriaId, 'activo': 1,
      });
      for (var entry in precios.entries) {
        await txn.insert('precios', {
          'producto_id': prodId, 'punto_venta_id': entry.key, 'precio': entry.value,
        });
      }
      return prodId;
    });
  }

  Future<void> actualizarProductoConPrecios({
    required int productoId,
    required String codigo,
    required String nombre,
    required int categoriaId,
    required Map<int, double> precios,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('productos', {
        'codigo': codigo, 'nombre': nombre, 'categoria_id': categoriaId,
      }, where: 'id = ?', whereArgs: [productoId]);

      for (var entry in precios.entries) {
        final existe = await txn.query('precios',
            where: 'producto_id = ? AND punto_venta_id = ?',
            whereArgs: [productoId, entry.key]);
        if (existe.isEmpty) {
          await txn.insert('precios', {
            'producto_id': productoId, 'punto_venta_id': entry.key, 'precio': entry.value,
          });
        } else {
          await txn.update('precios', {'precio': entry.value},
              where: 'producto_id = ? AND punto_venta_id = ?',
              whereArgs: [productoId, entry.key]);
        }
      }
    });
  }

  Future<void> eliminarProductoLogico(int productoId) async {
    final db = await database;
    await db.update('productos', {'activo': 0}, where: 'id = ?', whereArgs: [productoId]);
  }

  Future<void> reactivarProducto(int productoId) async {
    final db = await database;
    await db.update('productos', {'activo': 1}, where: 'id = ?', whereArgs: [productoId]);
  }

  Future<String?> getParametro(String clave) async {
    final db = await database;
    final r = await db.query('parametros', where: 'clave = ?', whereArgs: [clave]);
    if (r.isEmpty) return null;
    return r.first['valor'] as String?;
  }

  Future<void> setParametro(String clave, String valor) async {
    final db = await database;
    await db.insert('parametros', {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _loadCache() async {
    final db = await database;
    _cachedProducts = await db.query('productos', where: 'activo = 1');
    notifyListeners();
  }

  List<Map<String, dynamic>> get products => _cachedProducts;

  Future<void> registrarVenta(Map<String, dynamic> ventaData, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      int ventaId = await txn.insert('ventas', ventaData);
      for (var item in items) {
        await txn.insert('detalle_venta', {
          'venta_id': ventaId,
          'producto_id': item['id'],
          'cantidad': item['qty'],
          'precio_unitario': item['price'],
          'subtotal': item['qty'] * item['price'],
        });
        await txn.rawUpdate(
          'UPDATE inventario SET stock = stock - ? WHERE producto_id = ? AND punto_venta_id = ? AND fecha = ?',
          [item['qty'], item['id'], ventaData['punto_venta_id'], DateTime.now().toIso8601String().split('T')[0]],
        );
      }
    });
  }

  Future<void> registrarGasto(String categoria, String desc, double monto, int tieneComp) async {
    final db = await database;
    await db.insert('gastos_internos', {
      'fecha': DateTime.now().toIso8601String(),
      'categoria': categoria,
      'descripcion': desc,
      'monto': monto,
      'tiene_comprobante': tieneComp,
      'usuario_id': 1,
    });
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getResumenMensual() async {
    final db = await database;
    String mesActual = DateTime.now().toIso8601String().substring(0, 7);
    var ventas = await db.rawQuery('SELECT SUM(monto_total) as total FROM ventas WHERE fecha LIKE ?', ['$mesActual%']);
    var gastos = await db.rawQuery('SELECT SUM(monto) as total FROM gastos_internos WHERE fecha LIKE ?', ['$mesActual%']);
    double totalVentas = ventas.first['total'] == null ? 0.0 : (ventas.first['total'] as num).toDouble();
    double totalGastos = gastos.first['total'] == null ? 0.0 : (gastos.first['total'] as num).toDouble();
    return [{'ventas': totalVentas, 'gastos': totalGastos, 'utilidad': totalVentas - totalGastos}];
  }

  Future<List<Map<String, dynamic>>> consultarCuentasPendientes() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, 
             COALESCE((SELECT SUM(monto_cobrado) FROM cobros WHERE cuenta_id = c.id), 0) as total_abonado
      FROM cuentas_por_cobrar c
      WHERE c.estado != 'PAGADO'
      ORDER BY c.fecha_venta ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> consultarCierresDelDia(String fecha) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, pv.codigo as pv_codigo, pv.nombre as pv_nombre
      FROM cierres_caja c
      LEFT JOIN puntos_venta pv ON c.punto_venta_id = pv.id
      WHERE c.fecha = ?
      ORDER BY pv.id
    ''', [fecha]);
  }

  Future<String> generarCodigoTransferencia(String tipo) async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final fechaCompacta = hoy.replaceAll('-', '');
    final movs = await db.rawQuery(
      'SELECT COUNT(*) as total FROM transferencias WHERE codigo LIKE ?',
      ['$tipo-$fechaCompacta-%'],
    );
    final sec = ((movs.first['total'] as int?) ?? 0) + 1;
    return '$tipo-$fechaCompacta-${sec.toString().padLeft(3, '0')}';
  }

  Future<List<Map<String, dynamic>>> getStockPuntoVenta(int pvId) async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    return await db.rawQuery('''
      SELECT i.*, p.codigo as prod_codigo, p.nombre as prod_nombre
      FROM inventario i
      LEFT JOIN productos p ON i.producto_id = p.id
      WHERE i.punto_venta_id = ? AND i.fecha = ? AND i.stock > 0
      ORDER BY p.codigo ASC
    ''', [pvId, hoy]);
  }

  Future<void> registrarTrasladoCompleto({
    required int origenId,
    required int destinoId,
    required int usuarioId,
    required List<Map<String, dynamic>> items,
    required String tipo,
  }) async {
    final db = await database;
    final codigo = await generarCodigoTransferencia(tipo);
    final ahora = DateTime.now().toIso8601String();

    for (var item in items) {
      await db.insert('transferencias', {
        'fecha': ahora,
        'producto_id': item['producto_id'],
        'cantidad': item['cantidad'],
        'cantidad_recibida': 0,
        'origen_id': origenId,
        'destino_id': destinoId,
        'usuario_id': usuarioId,
        'tipo': tipo,
        'codigo': codigo,
        'estado': 'PENDIENTE',
      });
    }
  }

  Future<List<Map<String, dynamic>>> getTrasladosPendientes(int pvId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, p.codigo as prod_codigo, p.nombre as prod_nombre,
             o.nombre as origen_nombre, o.codigo as origen_codigo
      FROM transferencias t
      LEFT JOIN productos p ON t.producto_id = p.id
      LEFT JOIN puntos_venta o ON t.origen_id = o.id
      WHERE t.destino_id = ? AND t.estado = 'PENDIENTE'
      ORDER BY t.codigo ASC, p.codigo ASC
    ''', [pvId]);
  }

  Future<void> recibirTraslado({
    required String codigo,
    required int destinoId,
    required List<Map<String, dynamic>> itemsConCantidad,
  }) async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T')[0];

    for (var item in itemsConCantidad) {
      final id = item['id'] as int;
      final cantRecibida = item['cantidad_recibida'] as int;
      final prodId = item['producto_id'] as int;

      await db.update('transferencias', {
        'cantidad_recibida': cantRecibida,
        'estado': 'RECIBIDO',
      }, where: 'id = ?', whereArgs: [id]);

      final existente = await db.query('inventario',
          where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?',
          whereArgs: [prodId, destinoId, hoy]);

      if (existente.isEmpty) {
        await db.insert('inventario', {
          'producto_id': prodId,
          'punto_venta_id': destinoId,
          'stock': cantRecibida,
          'fecha': hoy,
        });
      } else {
        final actual = (existente.first['stock'] as num?)?.toInt() ?? 0;
        await db.update('inventario', {'stock': actual + cantRecibida},
            where: 'id = ?', whereArgs: [existente.first['id']]);
      }
    }
  }

  Future<void> ejecutarDesmedroGlobal(int pvId, int usuarioId) async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T')[0];

    final stock = await db.query('inventario',
        where: 'punto_venta_id = ? AND fecha = ?', whereArgs: [pvId, hoy]);

    int totalDesmedrado = 0;
    for (var s in stock) {
      final cant = (s['stock'] as num?)?.toInt() ?? 0;
      totalDesmedrado += cant;
      await db.update('inventario', {'stock': 0},
          where: 'id = ?', whereArgs: [s['id']]);
    }

    await db.insert('auditoria_cambios', {
      'fecha': DateTime.now().toIso8601String(),
      'usuario_id': usuarioId,
      'usuario_nombre': 'Sistema',
      'tabla_afectada': 'inventario',
      'accion': 'DESMEDRO_GLOBAL',
      'registro_id': pvId,
      'datos_anteriores': 'Stock: $totalDesmedrado uds',
      'datos_nuevos': 'Stock: 0 uds',
    });
  }
}