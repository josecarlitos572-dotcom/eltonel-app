import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [
      BarcodeFormat.pdf417, // DNI Azul
      BarcodeFormat.code39, // Carnet Extranjería / Licencia
      BarcodeFormat.qrCode, // Licencia de Conducir
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _procesando = false;

  // 1. FLUJO RÁPIDO: Código de barras
  void _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;
    final barcode = capture.barcodes.first;
    final raw = barcode.rawValue;
    if (raw == null) return;

    setState(() => _procesando = true);
    await _controller.stop();

    Map<String, dynamic> datosCliente = {};

    if (barcode.format == BarcodeFormat.pdf417) {
      datosCliente = _parseDNIAzul(raw);
    } else if (barcode.format == BarcodeFormat.code39) {
      datosCliente = {'tipo': 'CE_LICENCIA', 'numero': raw, 'nombre': 'Cliente Extranjero'};
    } else if (barcode.format == BarcodeFormat.qrCode) {
      datosCliente = _parseQR(raw);
    }

    if (datosCliente.isEmpty) {
      datosCliente = {'tipo': 'DESCONOCIDO', 'raw': raw};
    }

    Navigator.pop(context, datosCliente);
  }

  // Parser DNI Azul (Lógica de bytes)
  Map<String, dynamic> _parseDNIAzul(String raw) {
    try {
      // En el DNI Azul, el PDF417 contiene los datos en posiciones específicas.
      // Este es un parser simplificado que busca el número de DNI.
      // El DNI empieza en el byte 2 y termina en el 10.
      if (raw.length > 10) {
        String dni = raw.substring(2, 10);
        String nombre = raw.substring(90, 125).trim(); // Nombres
        String apellido = raw.substring(10, 50).trim(); // Apellidos
        return {
          'tipo': 'DNI_AZUL',
          'numero': dni,
          'nombre': '$nombre $apellido',
        };
      }
    } catch (e) {
      // Fallback
    }
    return {'tipo': 'DNI_AZUL', 'numero': raw, 'nombre': 'Cliente DNI'};
  }

  Map<String, dynamic> _parseQR(String raw) {
    // Las licencias suelen tener un QR con el número de licencia
    return {'tipo': 'LICENCIA', 'numero': raw, 'nombre': 'Cliente Licencia'};
  }

  // 2. FLUJO LENTO: OCR para MRZ (DNI Electrónico)
  Future<void> _escanearMRZ() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _procesando = true);
    await _controller.stop();

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      // Buscar la línea MRZ (suele tener '<' y caracteres en mayúscula)
      String mrzData = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          if (line.text.contains('<') && line.text.length > 20) {
            mrzData += line.text + '\n';
          }
        }
      }

      // Parseo básico de MRZ para extraer el número de documento
      String numeroDoc = '';
      if (mrzData.isNotEmpty) {
        final lines = mrzData.split('\n');
        if (lines.isNotEmpty) {
          // La primera línea suele tener el tipo de doc y el país.
          // La segunda línea tiene el número de documento.
          if (lines.length > 1) {
            final secondLine = lines[1];
            // Los primeros 9 caracteres de la segunda línea son el número de documento
            numeroDoc = secondLine.substring(0, 9).replaceAll('<', '').trim();
          }
        }
      }

      Navigator.pop(context, {
        'tipo': 'DNI_ELECTRONICO',
        'numero': numeroDoc,
        'nombre': 'Cliente MRZ',
      });

    } catch (e) {
      Navigator.pop(context, {'tipo': 'ERROR', 'error': e.toString()});
    } finally {
      setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ESCANEAR DOCUMENTO')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Botón flotante para el OCR (DNI Electrónico)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _procesando ? null : _escanearMRZ,
              icon: const Icon(Icons.camera_alt),
              label: const Text('DNI ELECTRÓNICO / MRZ (FOTO)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}