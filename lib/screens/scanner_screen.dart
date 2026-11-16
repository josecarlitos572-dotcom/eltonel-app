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
      BarcodeFormat.code39, // Carnet Extranjería / Licencia
      BarcodeFormat.qrCode, // QR genéricos
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

  Map<String, dynamic> _parseDNIAzul(String raw) {
    try {
      if (raw.length > 10) {
        // Intento de parseo básico para el DNI azul
        String dni = raw.substring(2, 10);
        // En un parser real, aquí extraes nombres y apellidos por posiciones
        return {
          'tipo': 'DNI_AZUL',
          'numero': dni,
          'nombre': 'Cliente DNI',
        };
      }
    } catch (e) {}
    return {'tipo': 'DNI_AZUL', 'numero': raw, 'nombre': 'Cliente DNI'};
  }

  Map<String, dynamic> _parseQR(String raw) {
    return {'tipo': 'QR', 'numero': raw, 'nombre': 'Cliente QR'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESCANEAR DOCUMENTO')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Apunta al código de barras (DNI azul o Carné de Extranjería)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}