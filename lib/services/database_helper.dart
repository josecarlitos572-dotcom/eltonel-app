import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper extends ChangeNotifier {
  static Database? _database;
  List<Map<String, dynamic>> _cachedProducts = [];

  static const String dbName = 'eltonel_v14.db'; // CAMBIO DE NOMBRE PARA FORZAR NUEVA BD

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _loadCache();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 14,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ... (TABLAS ANTERIORES SE MANTIENEN IGUAL) ...
    await db.execute('''CREATE TABLE puntos_venta (id INTEGER PRIMARY KEY, nombre TEXT, codigo TEXT UNIQUE, direccion TEXT, dia_descanso TEXT, ini_vta TEXT, fin_vta TEXT, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE categorias_producto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, abreviatura TEXT, orden INTEGER DEFAULT 0, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE categorias_gasto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, limite_max REAL DEFAULT 9999, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT UNIQUE, nombre TEXT, categoria_id INTEGER, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE precios (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, punto_venta_id INTEGER, precio REAL)''');
    await db.execute('''CREATE TABLE personal (id INTEGER PRIMARY KEY AUTOINCREMENT, apellidos TEXT, nombres TEXT, dni TEXT UNIQUE, fono TEXT, rol TEXT, password TEXT, punto_venta_id INTEGER, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, dni TEXT, fono TEXT, direccion TEXT, activo INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE inventario (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, punto_venta_id INTEGER, stock INTEGER, fecha TEXT)''');
    
    // TABLA VENTAS MODIFICADA
    await db.execute('''CREATE TABLE ventas (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      cliente_id INTEGER, 
      usuario_id INTEGER, 
      punto_venta_id INTEGER, 
      fecha TEXT, 
      tipo_venta TEXT, 
      monto_total REAL, 
      vuelto REAL, 
      tiene_comprobante INTEGER DEFAULT 0, 
      nombre_cliente TEXT, 
      telefono_cliente TEXT, 
      dni_cliente TEXT, 
      base_imponible REAL DEFAULT 0,
      igv REAL DEFAULT 0,
      estado_comanda TEXT DEFAULT 'PENDIENTE',
      fecha_vencimiento TEXT
    )''');

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
    // Como cambiamos el nombre a v14, esto no se ejecutará en instalaciones nuevas.
    // Pero si tuvieras una v13, aquí harías los ALTER TABLE.
  }

  Future<void> _seedSystem(Database db) async {
    // ... (MISMO SEED DE ANTES) ...
    await db.insert('puntos_venta', {'id': 1, 'nombre': 'LA BASE', 'codigo': 'BASE', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('puntos_venta', {'id': 2, 'nombre': 'Santa Rosa', 'codigo': 'SR1', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('puntos_venta', {'id': 3, 'nombre': 'Víctor Raúl 1', 'codigo': 'VR1', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});
    await db.insert('puntos_venta', {'id': 4, 'nombre': 'Víctor Raúl 2', 'codigo': 'VR2', 'direccion': '', 'dia_descanso': 'dom', 'ini_vta': '03:00', 'fin_vta': '11:00'});

    await db.insert('categorias_gasto', {'nombre': 'SS.HH.', 'limite_max': 2.0});
    // ... resto de gastos ...

    await db.insert('personal', {
      'apellidos': 'ADMIN', 'nombres': 'PRINCIPAL', 'dni': '09878372',
      'rol': 'ADMIN', 'password': 'JOse\$\$11', 'punto_venta_id': 0
    });

    await _seedProductosYCategorias(db);
    await _seedParametros(db);
  }

  Future<void> _seedParametros(Database db) async {
    final params = [
      {'clave': 'empresa_nombre', 'valor': 'Desayunos El Tonel', 'descripcion': 'Nombre de la empresa'},
      {'clave': 'igv', 'valor': '18', 'descripcion': 'Porcentaje de IGV'},
      {'clave': 'rer', 'valor': '1.5', 'descripcion': 'Porcentaje de RER'},
      // ... resto de params ...
    ];
    for (var p in params) {
      await db.insert('parametros', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ... (RESTO DE MÉTODOS: getProductos, registrarVenta, etc.) ...

  // NUEVO MÉTODO: Registrar venta con cálculo de IGV y comanda
  Future<void> registrarVenta(Map<String, dynamic> ventaData, List<Map<String, dynamic>> items, {bool esCredito = false}) async {
    final db = await database;
    
    // Calcular IGV (18%) y Base Imponible
    double total = (ventaData['monto_total'] as num).toDouble();
    double baseImponible = total / 1.18;
    double igv = total - baseImponible;

    ventaData['base_imponible'] = double.parse(baseImponible.toStringAsFixed(2));
    ventaData['igv'] = double.parse(igv.toStringAsFixed(2));
    ventaData['estado_comanda'] = 'PENDIENTE';

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
        
        final hoy = DateTime.now().toIso8601String().split('T')[0];
        final existeInv = await txn.query('inventario', 
          where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?',
          whereArgs: [item['id'], ventaData['punto_venta_id'], hoy]
        );

        if (existeInv.isEmpty) {
          await txn.insert('inventario', {
            'producto_id': item['id'],
            'punto_venta_id': ventaData['punto_venta_id'],
            'stock': -(item['qty'] as int),
            'fecha': hoy,
          });
        } else {
          await txn.rawUpdate(
            'UPDATE inventario SET stock = stock - ? WHERE producto_id = ? AND punto_venta_id = ? AND fecha = ?',
            [item['qty'], item['id'], ventaData['punto_venta_id'], hoy],
          );
        }
      }

      if (esCredito) {
        await txn.insert('cuentas_por_cobrar', {
          'venta_id': ventaId,
          'cliente_id': ventaData['cliente_id'],
          'cliente_nombre': ventaData['nombre_cliente'],
          'cliente_telefono': ventaData['telefono_cliente'],
          'monto_original': ventaData['monto_total'],
          'monto_pagado': 0.0,
          'saldo_pendiente': ventaData['monto_total'],
          'fecha_venta': ventaData['fecha'],
          'fecha_vencimiento': DateTime.now().add(Duration(days: 7)).toIso8601String(),
          'estado': 'PENDIENTE',
          'punto_venta_id': ventaData['punto_venta_id'],
        });
      }
    });
  }
}