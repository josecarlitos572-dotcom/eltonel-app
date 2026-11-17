import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';

/// Servicio de Batches — Comunicación 100% Offline
class BatchService {
  static const String TIPO_CIERRE = 'CIERRE_JORNADA';
  static const String TIPO_REQUERIMIENTO = 'REQUERIMIENTO';
  static const String TIPO_TRASLADO = 'CONFIRMA_TRASLADO';
  static const String TIPO_PRODUCTOS = 'PRODUCTOS';
  static const String TIPO_PRECIOS = 'PRECIOS';
  static const String TIPO_ABASTO = 'ABASTO';
  static const String TIPO_USUARIOS = 'USUARIOS';
  static const String TIPO_MAESTRO = 'MAESTRO'; // NUEVO: maestros + stock inicial

  static String _calcularHash(Map<String, dynamic> payload) {
    final bytes = utf8.encode(jsonEncode(payload));
    return 'sha256:${sha256.convert(bytes)}';
  }

  static Future<String> _obtenerHashAnterior(Database db, String origen) async {
    final r = await db.rawQuery('SELECT hash FROM batches_generados WHERE origen = ? ORDER BY id DESC LIMIT 1', [origen]);
    return r.isEmpty ? 'sha256:0000000000000000000000000000000000000000000000000000000000000000' : r.first['hash'] as String;
  }

  static Future<Map<String, dynamic>> generarBatchCierre({required Database db, required String origen, required String destino, required String periodo, required int puntoVentaId}) async {
    final payload = {
      'resumen_caja': await _obtenerResumenCaja(db, puntoVentaId, periodo),
      'ventas': await _obtenerVentas(db, puntoVentaId, periodo),
      'gastos': await _obtenerGastos(db, puntoVentaId, periodo),
      'quiebres': await _obtenerQuiebres(db, puntoVentaId, periodo),
      'cuentas_por_cobrar': await _obtenerCuentasPorCobrar(db, puntoVentaId),
      'abonos': await _obtenerAbonos(db, puntoVentaId, periodo),
      'stock_final': await _obtenerStockFinal(db, puntoVentaId, periodo),
    };
    return _armarYRegistrar(db, origen, destino, periodo, TIPO_CIERRE, payload);
  }

  // NUEVO: batch MAESTRO con personal, asignaciones, productos, categorías,
  // precios del PV destino y parámetros. Permite que un equipo nuevo del
  // vendedor loguee y venda sin depender del seed local.
  static Future<Map<String, dynamic>> generarBatchMaestro({required Database db, required String origen, required String destino, required String periodo, required int pvDestinoId, List<Map<String, dynamic>> items = const []}) async {
    final personal = await db.query('personal', where: 'activo = 1');
    final asignaciones = await db.query('asignaciones_diarias', where: 'fecha = ? AND estado = ?', whereArgs: [periodo, 'ACTIVO']);
    final productos = await db.query('productos', where: 'activo = 1');
    final categorias = await db.query('categorias_producto', where: 'activo = 1');
    final precios = await db.query('precios', where: 'punto_venta_id = ?', whereArgs: [pvDestinoId]);
    final parametros = await db.query('parametros');
    final payload = {
      'personal': personal,
      'asignaciones_diarias': asignaciones,
      'productos': productos,
      'categorias_producto': categorias,
      'precios': precios,
      'parametros': parametros,
      'items': items, // stock inicial opcional
    };
    return _armarYRegistrar(db, origen, destino, periodo, TIPO_MAESTRO, payload);
  }

  // Ensambla header (hash + cadena) y persiste en batches_generados.
  static Future<Map<String, dynamic>> _armarYRegistrar(Database db, String origen, String destino, String periodo, String tipo, Map<String, dynamic> payload) async {
    final hash = _calcularHash(payload);
    final hashAnterior = await _obtenerHashAnterior(db, origen);
    final sec = (((await db.rawQuery('SELECT COUNT(*) as total FROM batches_generados WHERE origen = ? AND tipo = ?', [origen, tipo])).first['total'] as int?) ?? 0) + 1;
    final batch = {
      'header': {'tipo': tipo, 'version': 1, 'origen': origen, 'destino': destino, 'fecha_generacion': DateTime.now().toIso8601String(), 'periodo': periodo, 'secuencial': sec, 'hash_anterior': hashAnterior, 'hash': hash},
      'payload': payload,
    };
    await db.insert('batches_generados', {'tipo': tipo, 'origen': origen, 'destino': destino, 'periodo': periodo, 'secuencial': sec, 'hash': hash, 'hash_anterior': hashAnterior, 'contenido_json': jsonEncode(batch), 'fecha_generacion': DateTime.now().toIso8601String(), 'estado': 'GENERADO'});
    return batch;
  }

  // NUEVO: aplica un batch MAESTRO sobre la BD local (upsert por clave natural).
  static Future<Map<String, dynamic>> aplicarBatchMaestro(Database db, Map<String, dynamic> payload, int pvId, String hoy) async {
    int nPersonal = 0, nAsig = 0, nProd = 0, nCat = 0, nPrecio = 0, nStock = 0;
    for (final p in (payload['personal'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(p);
      final ex = await db.query('personal', where: 'dni = ?', whereArgs: [m['dni']]);
      if (ex.isEmpty) { await db.insert('personal', m); } else { m['id'] = ex.first['id']; await db.update('personal', m, where: 'id = ?', whereArgs: [m['id']]); }
      nPersonal++;
    }
    for (final c in (payload['categorias_producto'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(c);
      final ex = await db.query('categorias_producto', where: 'nombre = ?', whereArgs: [m['nombre']]);
      if (ex.isEmpty) { await db.insert('categorias_producto', m); } else { m['id'] = ex.first['id']; await db.update('categorias_producto', m, where: 'id = ?', whereArgs: [m['id']]); }
      nCat++;
    }
    for (final pr in (payload['productos'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(pr);
      final ex = await db.query('productos', where: 'codigo = ?', whereArgs: [m['codigo']]);
      if (ex.isEmpty) { await db.insert('productos', m); } else { m['id'] = ex.first['id']; await db.update('productos', m, where: 'id = ?', whereArgs: [m['id']]); }
      nProd++;
    }
    for (final a in (payload['asignaciones_diarias'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(a);
      final ex = await db.query('asignaciones_diarias', where: 'fecha = ? AND usuario_id = ? AND punto_venta_id = ?', whereArgs: [m['fecha'], m['usuario_id'], m['punto_venta_id']]);
      if (ex.isEmpty) { await db.insert('asignaciones_diarias', m); nAsig++; }
    }
    for (final pc in (payload['precios'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(pc);
      final ex = await db.query('precios', where: 'producto_id = ? AND punto_venta_id = ?', whereArgs: [m['producto_id'], m['punto_venta_id']]);
      if (ex.isEmpty) { await db.insert('precios', m); } else { await db.update('precios', {'precio': m['precio']}, where: 'id = ?', whereArgs: [ex.first['id']]); }
      nPrecio++;
    }
    for (final pt in (payload['parametros'] as List? ?? [])) {
      await db.insert('parametros', Map<String, dynamic>.from(pt), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final item in (payload['items'] as List? ?? [])) {
      final prodId = item['producto_id'] as int; final cant = (item['cantidad'] as num).toInt(); if (cant <= 0) continue;
      final ex = await db.query('inventario', where: 'producto_id = ? AND punto_venta_id = ? AND fecha = ?', whereArgs: [prodId, pvId, hoy]);
      if (ex.isEmpty) { await db.insert('inventario', {'producto_id': prodId, 'punto_venta_id': pvId, 'stock': cant, 'fecha': hoy}); } else { await db.update('inventario', {'stock': ((ex.first['stock'] as num?)?.toInt() ?? 0) + cant}, where: 'id = ?', whereArgs: [ex.first['id']]); }
      nStock += cant;
    }
    return {'personal': nPersonal, 'asignaciones': nAsig, 'productos': nProd, 'categorias': nCat, 'precios': nPrecio, 'stock': nStock};
  }

  static Future<bool> enviarPorWhatsApp({required Map<String, dynamic> batch, required String telefonoDestino, String? mensajeAdicional}) async {
    final jsonStr = jsonEncode(batch);
    final url = 'https://wa.me/$telefonoDestino?text=${Uri.encodeComponent(mensajeAdicional != null ? '$mensajeAdicional\n\n$jsonStr' : jsonStr)}';
    if (await canLaunchUrl(Uri.parse(url))) { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); return true; }
    return false;
  }

  static Future<String?> guardarYCompartirArchivo({required Map<String, dynamic> batch, required String nombreArchivo}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$nombreArchivo.json');
      await file.writeAsString(jsonEncode(batch));
      await Share.shareXFiles([XFile(file.path)], subject: 'Batch El Tonel - $nombreArchivo');
      return file.path;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> importarBatch({required Database db, required String jsonContenido}) async {
    try {
      final batch = jsonDecode(jsonContenido) as Map<String, dynamic>;
      final header = batch['header'] as Map<String, dynamic>;
      final payload = batch['payload'] as Map<String, dynamic>;
      final hashEsperado = header['hash'] as String;
      if (hashEsperado != _calcularHash(payload)) return {'exito': false, 'error': 'HASH_INVALIDO', 'detalle': 'Contenido modificado o corrupto'};
      if ((await db.query('batches_recibidos', where: 'hash = ?', whereArgs: [hashEsperado])).isNotEmpty) return {'exito': false, 'error': 'DUPLICADO', 'detalle': 'Este batch ya fue importado'};
      final ultimo = await db.rawQuery('SELECT hash FROM batches_recibidos WHERE origen = ? ORDER BY id DESC LIMIT 1', [header['origen']]);
      if (ultimo.isNotEmpty && (ultimo.first['hash'] as String) != (header['hash_anterior'] as String)) return {'exito': false, 'error': 'GAP_DETECTADO', 'detalle': 'Falta un batch intermedio'};
      final batchId = await db.insert('batches_recibidos', {'tipo': header['tipo'], 'origen': header['origen'], 'destino': header['destino'], 'periodo': header['periodo'], 'secuencial': header['secuencial'], 'hash': hashEsperado, 'hash_anterior': header['hash_anterior'], 'contenido_json': jsonContenido, 'fecha_generacion': header['fecha_generacion'], 'fecha_recepcion': DateTime.now().toIso8601String(), 'estado': 'RECIBIDO'});
      return {'exito': true, 'batch_id': batchId, 'tipo': header['tipo'], 'origen': header['origen'], 'payload': payload};
    } catch (e) { return {'exito': false, 'error': 'ERROR_PARSEO', 'detalle': e.toString()}; }
  }

  static Future<Map<String, dynamic>> _obtenerResumenCaja(Database db, int puntoId, String periodo) async {
    final ventas = await db.rawQuery('SELECT SUM(monto_total) as total FROM ventas WHERE punto_venta_id = ? AND fecha LIKE ?', [puntoId, '$periodo%']);
    final gastos = await db.rawQuery('SELECT SUM(monto) as total FROM gastos_internos WHERE fecha LIKE ?', ['$periodo%']);
    final apertura = await db.query('aperturas_caja', where: 'punto_venta_id = ? AND fecha = ?', whereArgs: [puntoId, periodo]);
    return {'saldo_inicial': apertura.isNotEmpty ? apertura.first['saldo_inicial'] : 0.0, 'total_ventas': (ventas.first['total'] as num?)?.toDouble() ?? 0.0, 'total_gastos': (gastos.first['total'] as num?)?.toDouble() ?? 0.0};
  }
  static Future<List<Map<String, dynamic>>> _obtenerVentas(Database db, int p, String per) async => db.query('ventas', where: 'punto_venta_id = ? AND fecha LIKE ?', whereArgs: [p, '$per%'], orderBy: 'id ASC');
  static Future<List<Map<String, dynamic>>> _obtenerGastos(Database db, int p, String per) async => db.query('gastos_internos', where: 'fecha LIKE ?', whereArgs: ['$per%'], orderBy: 'id ASC');
  static Future<List<Map<String, dynamic>>> _obtenerQuiebres(Database db, int p, String per) async => db.query('quiebres', where: 'punto_venta_id = ? AND fecha LIKE ?', whereArgs: [p, '$per%'], orderBy: 'id ASC');
  static Future<List<Map<String, dynamic>>> _obtenerCuentasPorCobrar(Database db, int p) async => db.query('cuentas_por_cobrar', where: 'punto_venta_id = ? AND estado != ?', whereArgs: [p, 'PAGADO'], orderBy: 'fecha_venta ASC');
  static Future<List<Map<String, dynamic>>> _obtenerAbonos(Database db, int p, String per) async => db.query('cobros', where: 'fecha_cobro LIKE ?', whereArgs: ['$per%'], orderBy: 'id ASC');
  static Future<List<Map<String, dynamic>>> _obtenerStockFinal(Database db, int p, String per) async => db.query('inventario', where: 'punto_venta_id = ? AND fecha = ?', whereArgs: [p, per], orderBy: 'producto_id ASC');
}