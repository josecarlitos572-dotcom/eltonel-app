import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [
      BarcodeFormat.pdf417, // DNI Azul
      BarcodeFormat.code39, // Carné Extranjería
      BarcodeFormat.qrCode, // Licencia de Conducir
      // MRZ no es un formato de código de barras, es texto. 
      // mobile_scanner no lee MRZ directamente, pero podemos usar un OCR después.
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _procesando = false;

  void _onDetect(BarcodeCapture capture) {
    if (_procesando) return;
    final barcode = capture.barcodes.first;
    final raw = barcode.rawValue;
    if (raw == null) return;

    setState(() => _procesando = true);
    _controller.stop();

    // EL CEREBRO: Decidir qué hacer según el contenido
    Map<String, dynamic> datosCliente = {};

    // 1. Intentar parsear como DNI Azul (PDF417)
    if (barcode.format == BarcodeFormat.pdf417) {
      datosCliente = _parseDNIAzul(raw);
    } 
    // 2. Intentar parsear como Carné de Extranjería (Code39)
    else if (barcode.format == BarcodeFormat.code39) {
      datosCliente = _parseCarnetExtranjeria(raw);
    }
    // 3. Intentar parsear como Licencia de Conducir (QR)
    else if (barcode.format == BarcodeFormat.qrCode) {
      datosCliente = _parseLicenciaConducir(raw);
    }

    // Si no se pudo parsear, devolvemos el texto crudo para que el vendedor lo vea
    if (datosCliente.isEmpty) {
      datosCliente = {'raw': raw, 'error': 'Formato no reconocido'};
    }

    Navigator.pop(context, datosCliente);
  }

  Map<String, dynamic> _parseDNIAzul(String raw) {
    // Lógica de bytes del DNI peruano (1997)
    // Según peru-dni-reader: bytes 2-9 = numero, 10-49 = apellido1, etc.
    try {
      // La cadena raw puede tener caracteres especiales. 
      // En la práctica, el PDF417 se lee como una cadena de bytes.
      // Este es un parser simplificado. Para producción, usa la librería del repo.
      return {'tipo': 'DNI_AZUL', 'raw': raw};
    } catch (e) {
      return {};
    }
  }

  Map<String, dynamic> _parseCarnetExtranjeria(String raw) {
    // El Code39 del carné de extranjería contiene el número correlativo
    return {'tipo': 'CARNET_EXTRANJERIA', 'numero': raw};
  }

  Map<String, dynamic> _parseLicenciaConducir(String raw) {
    // El QR de la licencia contiene un JSON o texto con el número de licencia
    return {'tipo': 'LICENCIA', 'raw': raw};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ESCANEAR DOCUMENTO')),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}