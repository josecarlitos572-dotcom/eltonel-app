import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class ParametrosScreen extends StatefulWidget {
  @override
  _ParametrosScreenState createState() => _ParametrosScreenState();
}

class _ParametrosScreenState extends State<ParametrosScreen> {
  List<Map<String, dynamic>> _parametros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final data = await db.consultar('parametros', orderBy: 'clave ASC');
    setState(() {
      _parametros = data;
      _cargando = false;
    });
  }

  Future<void> _editar(Map<String, dynamic> param) async {
    final valorCtrl = TextEditingController(text: param['valor'] ?? '');

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'EDITAR PARÁMETRO',
          style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clave: ${param['clave']}',
              style: TextStyle(color: Colors.white70, fontFamily: 'CourierNew', fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              '${param['descripcion'] ?? ''}',
              style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 10),
            ),
            SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              decoration: InputDecoration(labelText: 'Valor'),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('CANCELAR', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('GUARDAR', style: TextStyle(color: Colors.yellow))),
        ],
      ),
    );

    if (resultado == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.setParametro(param['clave'] as String, valorCtrl.text.trim());
      _cargar();
    }
  }

  String _etiquetaClave(String clave) {
    switch (clave) {
      case 'empresa_nombre':
        return 'NOMBRE DE LA EMPRESA';
      case 'empresa_ruc':
        return 'RUC';
      case 'igv':
        return 'IGV (%)';
      case 'moneda':
        return 'MONEDA';
      case 'admin_whatsapp':
        return 'WHATSAPP ADMIN';
      case 'hora_cierre':
        return 'HORA DE CIERRE';
      case 'inactividad_minutos':
        return 'INACTIVIDAD (min)';
      case 'version_bd':
        return 'VERSIÓN BD';
      default:
        return clave.toUpperCase();
    }
  }

  IconData _iconoClave(String clave) {
    switch (clave) {
      case 'empresa_nombre':
        return Icons.business;
      case 'empresa_ruc':
        return Icons.badge;
      case 'igv':
        return Icons.percent;
      case 'moneda':
        return Icons.attach_money;
      case 'admin_whatsapp':
        return Icons.phone;
      case 'hora_cierre':
        return Icons.schedule;
      case 'inactividad_minutos':
        return Icons.timer;
      case 'version_bd':
        return Icons.storage;
      default:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PARÁMETROS DEL SISTEMA'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      backgroundColor: Colors.black,
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.yellow))
          : ListView.builder(
              itemCount: _parametros.length,
              itemBuilder: (context, i) {
                final p = _parametros[i];
                final clave = p['clave'] as String? ?? '';
                return ListTile(
                  leading: Icon(_iconoClave(clave), color: Colors.yellow),
                  title: Text(
                    _etiquetaClave(clave),
                    style: TextStyle(color: Colors.white, fontFamily: 'CourierNew', fontSize: 13),
                  ),
                  subtitle: Text(
                    'Valor: ${p['valor'] ?? ''}',
                    style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: Colors.yellow),
                    onPressed: () => _editar(p),
                  ),
                );
              },
            ),
    );
  }
}