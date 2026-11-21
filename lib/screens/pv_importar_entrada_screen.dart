import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class PvImportarEntradaScreen extends StatefulWidget {
  const PvImportarEntradaScreen({Key? key}) : super(key: key);

  @override
  State<PvImportarEntradaScreen> createState() => _PvImportarEntradaScreenState();
}

class _PvImportarEntradaScreenState extends State<PvImportarEntradaScreen> {
  static const Color _amber = Color(0xFFFFC107);
  static const Color _bg = Color(0xFF121212);
  static const Color _surface = Color(0xFF1E1E1E);
  static const Color _green = Color(0xFF43A047);
  static const Color _red = Color(0xFFD32F2F);

  final _ctrl = TextEditingController();
  bool _procesando = false;
  Map<String, dynamic>? _resultado;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pegar() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _ctrl.text = data!.text!);
  }

  Future<void> _recibir() async {
    final json = _ctrl.text.trim();
    if (json.isEmpty) { 
      setState(() => _resultado = {'ok': false, 'msg': 'Pega el JSON del batch primero.'}); 
      return; 
    }

    setState(() { _procesando = true; _resultado = null; });
    try {
      final db = context.read<DatabaseHelper>();
      final auth = context.read<AuthService>();
      final pvId = (auth.currentUser?['punto_venta_id_actual'] as int?) ??
          (auth.currentUser?['punto_venta_id'] as int?) ?? 0;
      
      if (pvId == 0) {
        setState(() { _procesando = false; _resultado = {'ok': false, 'msg': 'Error: Tu usuario no tiene un Punto de Venta asignado.'}; });
        return;
      }

      final res = await db.validarYRegistrarBatch(json, pvId);
      setState(() { _procesando = false; _resultado = res; });
    } catch (e) {
      setState(() { _procesando = false; _resultado = {'ok': false, 'msg': 'Error interno: $e'}; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        title: const Text('RECIBIR ENTRADA DEL DÍA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _amber),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega aquí el JSON del batch enviado por la BASE.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Se validan 9 filtros: versión, serie, destino, emisor, fecha (≤48h), correlativo consecutivo, cadena de hash, integridad de contenido y productos.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  TextField(
                    controller: _ctrl,
                    maxLines: 10,
                    readOnly: _procesando,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '{"header":{...},"payload":{...}}',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  const Divider(color: Color(0xFF2E2E2E), height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _procesando ? null : _pegar,
                          icon: const Icon(Icons.paste, color: _amber, size: 18),
                          label: const Text('PEGAR', style: TextStyle(color: _amber)),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _procesando ? null : () => setState(() { _ctrl.clear(); _resultado = null; }),
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          label: const Text('LIMPIAR', style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _procesando ? Colors.grey : _amber, 
                  foregroundColor: Colors.black
                ),
                onPressed: _procesando ? null : _recibir,
                icon: _procesando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.inventory),
                label: Text(_procesando ? 'VALIDANDO...' : 'VALIDAR Y RECIBIR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            if (_resultado != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_resultado!['ok'] == true) ? _green.withOpacity(.15) : _red.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (_resultado!['ok'] == true) ? _green : _red),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      (_resultado!['ok'] == true) ? Icons.check_circle : Icons.error,
                      color: (_resultado!['ok'] == true) ? _green : _red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resultado!['msg'] as String,
                        style: TextStyle(
                          color: (_resultado!['ok'] == true) ? _green : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_resultado!['ok'] == true) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, minimumSize: const Size(0, 50)),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('VOLVER A VENTAS'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}