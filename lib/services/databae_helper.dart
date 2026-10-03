import 'package:sqflite/sqflite.dart'; // REM: Librería para base de datos SQLite local
import 'package:path/path.dart'; // REM: Utilidad para construir rutas de archivos seguras
import 'package:flutter/foundation.dart'; // REM: Proporciona ChangeNotifier para gestión de estado

class DatabaseHelper extends ChangeNotifier { // REM: Clase gestora de DB que notifica cambios a la UI
  static Database? _database; // REM: Instancia única de la base de datos (Singleton)
  List<Map<String, dynamic>> _cachedProducts = []; // REM: Caché en memoria para carga instantánea de productos

  Future<Database> get database async { // REM: Getter asíncrono para obtener la DB
    if (_database != null) return _database!; // REM: Si ya existe, la retorna inmediatamente
    _database = await _initDatabase(); // REM: Si no, la inicializa desde cero o abre la existente
    await _loadCache(); // REM: Carga productos en RAM para evitar lecturas lentas repetidas
    return _database!; // REM: Retorna la base de datos lista para usar
  }

  Future<Database> _initDatabase() async { // REM: Función privada de inicialización
    String path = join(await getDatabasesPath(), 'eltonel.db'); // REM: Ruta física del archivo .db en el celular
    return await openDatabase( // REM: Abre o crea la base de datos
      path, // REM: Usa la ruta definida arriba
      version: 5, // REM: Versión 5 incluye tablas de personal, categorías y aperturas
      onCreate: _onCreate, // REM: Ejecuta esto solo si la DB es nueva
      onUpgrade: _onUpgrade // REM: Ejecuta esto si la versión aumenta
    );
  }

  Future<void> _onCreate(Database db, int version) async { // REM: Creación de estructura de tablas
    // REM: Tabla de puntos de venta físicos (Base, SR1, VR1, VR2)
    await db.execute('''CREATE TABLE puntos_venta (id INTEGER PRIMARY KEY, nombre TEXT, codigo TEXT UNIQUE, activo INTEGER DEFAULT 1)'''); 
    
    // REM: Tabla de categorías de gasto parametrizadas con límites máximos
    await db.execute('''CREATE TABLE categorias_gasto (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT UNIQUE NOT NULL, limite_max REAL DEFAULT 9999, activo INTEGER DEFAULT 1)'''); 
    
    // REM: Tabla de personal móvil vinculado a puntos de venta
    await db.execute('''CREATE TABLE personal (id INTEGER PRIMARY KEY AUTOINCREMENT, apellidos TEXT, nombres TEXT, dni TEXT UNIQUE, fono TEXT, rol TEXT, password TEXT, punto_venta_id INTEGER, activo INTEGER DEFAULT 1)'''); 
    
    // REM: Catálogo maestro de productos
    await db.execute('''CREATE TABLE productos (id INTEGER PRIMARY KEY, nombre TEXT, categoria_id INTEGER, activo INTEGER DEFAULT 1)'''); 
    
    // REM: Precios específicos por punto de venta
    await db.execute('''CREATE TABLE precios (id INTEGER PRIMARY KEY, producto_id INTEGER, punto_venta_id INTEGER, precio REAL)'''); 
    
    // REM: Inventario diario por punto de venta
    await db.execute('''CREATE TABLE inventario (id INTEGER PRIMARY KEY, producto_id INTEGER, punto_venta_id INTEGER, stock INTEGER, fecha TEXT)'''); 
    
    // REM: Cabecera de ventas realizadas
    await db.execute('''CREATE TABLE ventas (id INTEGER PRIMARY KEY, cliente_id INTEGER, usuario_id INTEGER, punto_venta_id INTEGER, fecha TEXT, tipo_venta TEXT, monto_total REAL, vuelto REAL, tiene_comprobante INTEGER DEFAULT 0, nombre_cliente TEXT, fecha_vencimiento TEXT)'''); 
    
    // REM: Detalle de productos por cada venta
    await db.execute('''CREATE TABLE detalle_venta (id INTEGER PRIMARY KEY, venta_id INTEGER, producto_id INTEGER, cantidad INTEGER, precio_unitario REAL, subtotal REAL)'''); 
    
    // REM: Registro de gastos operativos manuales
    await db.execute('''CREATE TABLE gastos_internos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, categoria TEXT NOT NULL, descripcion TEXT, monto REAL NOT NULL, tiene_comprobante INTEGER DEFAULT 0, usuario_id INTEGER)'''); 
    
    // REM: Cierre de caja diario con cuadre de diferencias
    await db.execute('''CREATE TABLE cierres_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, punto_venta_id INTEGER, personal_id INTEGER, saldo_inicial REAL DEFAULT 0, total_ventas REAL DEFAULT 0, total_gastos_manuales REAL DEFAULT 0, saldo_teorico REAL DEFAULT 0, saldo_real_contado REAL DEFAULT 0, diferencia REAL DEFAULT 0, observaciones TEXT)'''); 
    
    // REM: Apertura de jornada con registro de cambio inicial
    await db.execute('''CREATE TABLE aperturas_caja (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, punto_venta_id INTEGER, personal_id INTEGER, saldo_inicial REAL DEFAULT 0)'''); 
    
    // REM: Historial de transferencias de stock entre puntos
    await db.execute('''CREATE TABLE transferencias (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, producto_id INTEGER NOT NULL, cantidad INTEGER NOT NULL, origen_id INTEGER NOT NULL, destino_id INTEGER NOT NULL, usuario_id INTEGER)'''); 
    
    await _seedSystem(db); // REM: Llena datos obligatorios al crear la DB
  }

  Future<void> _seedSystem(Database db) async { // REM: Carga de datos semilla iniciales
    // REM: Puntos de venta oficiales
    await db.insert('puntos_venta', {'nombre': 'LA BASE', 'codigo': 'BASE'}); 
    await db.insert('puntos_venta', {'nombre': 'Santa Rosa', 'codigo': 'SR1'}); 
    await db.insert('puntos_venta', {'nombre': 'Víctor Raúl 1', 'codigo': 'VR1'}); 
    await db.insert('puntos_venta', {'nombre': 'Víctor Raúl 2', 'codigo': 'VR2'}); 
    
    // REM: Categorías de gasto parametrizadas con sus límites operativos
    await db.insert('categorias_gasto', {'nombre': 'SS.HH.', 'limite_max': 9999}); 
    await db.insert('categorias_gasto', {'nombre': 'Flete Llegada', 'limite_max': 6}); 
    await db.insert('categorias_gasto', {'nombre': 'Flete Salida', 'limite_max': 6}); 
    await db.insert('categorias_gasto', {'nombre': 'Flete Movimiento', 'limite_max': 9}); 
    await db.insert('categorias_gasto', {'nombre': 'Papel ó Servilleta', 'limite_max': 4}); 
    await db.insert('categorias_gasto', {'nombre': 'Vasos Plásticos', 'limite_max': 4}); 
    await db.insert('categorias_gasto', {'nombre': 'Rellenos Panes', 'limite_max': 12}); 
    await db.insert('categorias_gasto', {'nombre': 'Desayuno', 'limite_max': 6}); 

    // REM: Usuario Administrador por defecto
    await db.insert('personal', {'apellidos': 'Dueño', 'nombres': 'Admin', 'dni': '00000000', 'rol': 'admin', 'password': 'tonel123', 'punto_venta_id': 0}); 
    
    // REM: Producto ejemplo para pruebas
    await db.insert('productos', {'nombre': 'Sandwich Pollo', 'categoria_id': 1}); 
    await db.insert('precios', {'producto_id': 1, 'punto_venta_id': 1, 'precio': 2.00}); 
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async { // REM: Migración de versiones futuras
    // REM: Aquí se agregarían ALTER TABLE si se modifican estructuras en updates futuros
  }

  Future<void> _loadCache() async { // REM: Carga productos activos en memoria RAM
    final db = await database; // REM: Obtiene instancia de DB
    _cachedProducts = await db.query('productos', where: 'activo = 1'); // REM: Consulta solo productos habilitados
    notifyListeners(); // REM: Notifica a las pantallas que hay datos listos
  }

  List<Map<String, dynamic>> get products => _cachedProducts; // REM: Getter público para acceder a la lista de productos

  Future<void> registrarVenta(Map<String, dynamic> ventaData, List<Map<String, dynamic>> items) async { // REM: Proceso atómico de venta
    final db = await database; // REM: Obtiene DB
    await db.transaction((txn) async { // REM: Inicia transacción segura (todo o nada)
      int ventaId = await txn.insert('ventas', ventaData); // REM: Guarda cabecera de venta
      for (var item in items) { // REM: Itera sobre cada producto del carrito
        // REM: Guarda detalle de la venta
        await txn.insert('detalle_venta', {'venta_id': ventaId, 'producto_id': item['id'], 'cantidad': item['qty'], 'precio_unitario': item['price'], 'subtotal': item['qty'] * item['price']}); 
        // REM: Descuenta stock del punto de venta actual en tiempo real
        await txn.rawUpdate('UPDATE inventario SET stock = stock - ? WHERE producto_id = ? AND punto_venta_id = ? AND fecha = ?', [item['qty'], item['id'], ventaData['punto_venta_id'], DateTime.now().toIso8601String().split('T')[0]]); 
      }
    });
  }

  Future<void> registrarGasto(String categoria, String desc, double monto, int tieneComp) async { // REM: Registro de egreso operativo
    final db = await database; // REM: Obtiene DB
    // REM: Inserta gasto con fecha automática y usuario actual
    await db.insert('gastos_internos', {'fecha': DateTime.now().toIso8601String(), 'categoria': categoria, 'descripcion': desc, 'monto': monto, 'tiene_comprobante': tieneComp, 'usuario_id': 1}); 
    notifyListeners(); // REM: Notifica actualización de datos
  }

  Future<List<Map<String, dynamic>>> getResumenMensual() async { // REM: Cálculo de rentabilidad mensual
    final db = await database; // REM: Obtiene DB
    String mesActual = DateTime.now().toIso8601String().substring(0, 7); // REM: Extrae YYYY-MM del mes actual
    var ventas = await db.rawQuery('SELECT SUM(monto_total) as total FROM ventas WHERE fecha LIKE ?', ['$mesActual%']); // REM: Suma ventas del mes
    var gastos = await db.rawQuery('SELECT SUM(monto) as total FROM gastos_internos WHERE fecha LIKE ?', ['$mesActual%']); // REM: Suma gastos del mes
    double totalVentas = ventas.first['total'] == null ? 0.0 : (ventas.first['total'] as num).toDouble(); // REM: Convierte a double seguro
    double totalGastos = gastos.first['total'] == null ? 0.0 : (gastos.first['total'] as num).toDouble(); // REM: Convierte a double seguro
    return [{'ventas': totalVentas, 'gastos': totalGastos, 'utilidad': totalVentas - totalGastos}]; // REM: Retorna mapa con resultados
  }
}
