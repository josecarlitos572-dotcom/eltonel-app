import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class ExportService {
  Future<void> exportarMIGyEnviar(BuildContext context) async {
    try {
      // 1. Obtener la ruta de la base de datos
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'eltonel.db'); // CAMBIA POR EL NOMBRE DE TU BD
      final dbFile = File(path);

      if (!await dbFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró la base de datos')),
        );
        return;
      }

      // 2. Copiar a un archivo temporal
      final directory = await getTemporaryDirectory();
      final exportPath = '${directory.path}/MIG_ElTonel_${DateTime.now().millisecondsSinceEpoch}.db';
      await dbFile.copy(exportPath);

      // 3. Compartir por WhatsApp
      await Share.shareXFiles(
        [XFile(exportPath)],
        text: 'Cierre de turno El Tonel - ${DateTime.now().toString()}',
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }
}