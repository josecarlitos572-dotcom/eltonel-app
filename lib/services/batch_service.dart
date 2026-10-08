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

  // ═══════════════════════════════════════════════
  // 1. GENERAR HASH SHA-256
  // ═══════════════════════════════════════════════
  static String _calcularHash(Map<String, dynamic> payload) {
    final contenido = jsonEncode(payload);
    final bytes = utf8.encode(contenido);
    final digest = sha256.convert(bytes);
    return 'sha256:${digest.toString()}';
  }

  // ═══════════════════════════════════════════════
  // 2. OBTENER HASH ANTERIOR (encadenamiento)
  // ═══════════════════════════════════════════════
  static Future<String> _obtenerHashAnterior(Database db, String origen) async {
    final resultado = await db.rawQuery(
      'SELECT hash FROM batches_generados WHERE origen = ? ORDER BY id DESC LIMIT 1',
      [origen],
    );
    if (resultado.isEmpty) {
      return 'sha256:0000000000000000000000000000000000000000000000000000000000000000';
    }
    return resultado.first['hash'] as String;
  }

  // ═══════════════════════════════════════════════
  // 3. GENERAR BATCH DE CIERRE DE JORNADA
  // ═══════════════════════════════════════════════
  static Future<Map<String, dynamic>> generarBatchCierre({
    required Database db,
    required String origen,
    required String destino,
    required String periodo,
    required int puntoVentaId,
  }) async {
    final resumenCaja = await _obtenerResumenCaja(db, puntoVentaId, periodo);
    final ventas = await _obtenerVentas(db, puntoVentaId, periodo);
    final gastos = await _obtenerGastos(db, puntoVentaId, periodo);
    final quiebres = await _obtenerQuiebres(db, puntoVentaId, periodo);
    final cxc = await _obtenerCuentasPorCobrar(db, puntoVentaId);
    final abonos = await _obtenerAbonos(db, puntoVentaId, periodo);
    final stockFinal = await _obtenerStockFinal(db, puntoVentaId, periodo);

    final payload = {
      'resumen_caja': resumenCaja,
      'ventas': ventas,
      'gastos': gastos,
      'quiebres': quiebres,
      'cuentas_por_cobrar': cxc,
      'abonos': abonos,
      'stock_final': stockFinal,
    };

    final hashPayload = _calcularHash(payload);
    final hashAnterior = await _obtenerHashAnterior(db, origen);

    final sec = await db.rawQuery(
      'SELECT COUNT(*) as total FROM batches_generados WHERE origen = ?',
      [origen],
    );
    final secuencial = ((sec.first['total'] as int?) ?? 0) + 1;

    final batch = {
      'header': {
        'tipo': TIPO_CIERRE,
        'version': 1,
        'origen': origen,
        'destino': destino,
        'fecha_generacion': DateTime.now().toIso8601String(),
        'periodo': periodo,
        'secuencial': secuencial,
        'hash_anterior': hashAnterior,
        'hash': hashPayload,
      },
      'payload': payload,
    };

    await db.insert('batches_generados', {
      'tipo': TIPO_CIERRE,
      'origen': origen,
      'destino': destino,
      'periodo': periodo,
      'secuencial': secuencial,
      'hash': hashPayload,
      'hash_anterior': hashAnterior,
      'contenido_json': jsonEncode(batch),
      'fecha_generacion': DateTime.now().toIso8601String(),
      'estado': 'GENERADO',
    });

    return batch;
  }

  // ═══════════════════════════════════════════════
  // 4. ENVIAR POR WHATSAPP
  // ═══════════════════════════════════════════════
  static Future<bool> enviarPorWhatsApp({
    required Map<String, dynamic> batch,
    required String telefonoDestino,
    String? mensajeAdicional,
  }) async {
    final jsonStr = jsonEncode(batch);
    final mensaje = mensajeAdicional != null
        ? '$mensajeAdicional\n\n$jsonStr'
        : jsonStr;

    final url = 'https://wa.me/$telefonoDestino?text=${Uri.encodeComponent(mensaje)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════
  // 5. GUARDAR ARCHIVO Y COMPARTIR (Bluetooth/AirDrop/etc)
  // ═══════════════════════════════════════════════
  static Future<String?> guardarYCompartirArchivo({
    required Map<String, dynamic> batch,
    required String nombreArchivo,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$nombreArchivo.json');
      await file.writeAsString(jsonEncode(batch));

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Batch El Tonel - $nombreArchivo',
      );

      return file.path;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // 6. IMPORTAR BATCH
  // ═══════════════════════════════════════════════
  static Future<Map<String, dynamic>> importarBatch({
    required Database db,
    required String jsonContenido,
  }) async {
    try {
      final batch = jsonDecode(jsonContenido) as Map<String, dynamic>;
      final header = batch['header'] as Map<String, dynamic>;
      final payload = batch['payload'] as Map<String, dynamic>;

      final hashEsperado = header['hash'] as String;
      final hashCalculado = _calcularHash(payload);

      if (hashEsperado != hashCalculado) {
        return {
          'exito': false,
          'error': 'HASH_INVALIDO',
          'detalle': 'El contenido fue modificado o está corrupto',
        };
      }

      final existente = await db.query(
        'batches_recibidos',
        where: 'hash = ?',
        whereArgs: [hashEsperado],
      );
      if (existente.isNotEmpty) {
        return {
          'exito': false,
          'error': 'DUPLICADO',
          'detalle': 'Este batch ya fue importado',
        };
      }

      final hashAnteriorEsperado = header['hash_anterior'] as String;
      final ultimoBatch = await db.rawQuery(
        'SELECT hash FROM batches_recibidos WHERE origen = ? ORDER BY id DESC LIMIT 1',
        [header['origen']],
      );
      if (ultimoBatch.isNotEmpty) {
        final hashAnteriorReal = ultimoBatch.first['hash'] as String;
        if (hashAnteriorReal != hashAnteriorEsperado) {
          return {
            'exito': false,
            'error': 'GAP_DETECTADO',
            'detalle': 'Falta un batch intermedio',
          };
        }
      }

      final batchId = await db.insert('batches_recibidos', {
        'tipo': header['tipo'],
        'origen': header['origen'],
        'destino': header['destino'],
        'periodo': header['periodo'],
        'secuencial': header['secuencial'],
        'hash': hashEsperado,
        'hash_anterior': hashAnteriorEsperado,
        'contenido_json': jsonContenido,
        'fecha_generacion': header['fecha_generacion'],
        'fecha_recepcion': DateTime.now().toIso8601String(),
        'estado': 'RECIBIDO',
      });

      return {
        'exito': true,
        'batch_id': batchId,
        'tipo': header['tipo'],
        'origen': header['origen'],
      };
    } catch (e) {
      return {
        'exito': false,
        'error': 'ERROR_PARSEO',
        'detalle': e.toString(),
      };
    }
  }

  // ═══════════════════════════════════════════════
  // 7. MÉTODOS PRIVADOS — CONSULTAS
  // ═══════════════════════════════════════════════
  static Future<Map<String, dynamic>> _obtenerResumenCaja(
    Database db, int puntoId, String periodo) async {
    final ventas = await db.rawQuery(
      'SELECT SUM(monto_total) as total FROM ventas WHERE punto_venta_id = ? AND fecha LIKE ?',
      [puntoId, '$periodo%'],
    );
    final gastos = await db.rawQuery(
      'SELECT SUM(monto) as total FROM gastos_internos WHERE fecha LIKE ?',
      ['$periodo%'],
    );
    final apertura = await db.query(
      'aperturas_caja',
      where: 'punto_venta_id = ? AND fecha = ?',
      whereArgs: [puntoId, periodo],
    );

    return {
      'saldo_inicial': apertura.isNotEmpty ? apertura.first['saldo_inicial'] : 0.0,
      'total_ventas': (ventas.first['total'] as num?)?.toDouble() ?? 0.0,
      'total_gastos': (gastos.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  static Future<List<Map<String, dynamic>>> _obtenerVentas(
    Database db, int puntoId, String periodo) async {
    return await db.query(
      'ventas',
      where: 'punto_venta_id = ? AND fecha LIKE ?',
      whereArgs: [puntoId, '$periodo%'],
      orderBy: 'id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> _obtenerGastos(
    Database db, int puntoId, String periodo) async {
    return await db.query(
      'gastos_internos',
      where: 'fecha LIKE ?',
      whereArgs: ['$periodo%'],
      orderBy: 'id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> _obtenerQuiebres(
    Database db, int puntoId, String periodo) async {
    return await db.query(
      'quiebres',
      where: 'punto_venta_id = ? AND fecha LIKE ?',
      whereArgs: [puntoId, '$periodo%'],
      orderBy: 'id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> _obtenerCuentasPorCobrar(
    Database db, int puntoId) async {
    return await db.query(
      'cuentas_por_cobrar',
      where: 'punto_venta_id = ? AND estado != ?',
      whereArgs: [puntoId, 'PAGADO'],
      orderBy: 'fecha_venta ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> _obtenerAbonos(
    Database db, int puntoId, String periodo) async {
    return await db.query(
      'cobros',
      where: 'fecha_cobro LIKE ?',
      whereArgs: ['$periodo%'],
      orderBy: 'id ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> _obtenerStockFinal(
    Database db, int puntoId, String periodo) async {
    return await db.query(
      'inventario',
      where: 'punto_venta_id = ? AND fecha = ?',
      whereArgs: [puntoId, periodo],
      orderBy: 'producto_id ASC',
    );
  }
}