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
          style: TextStyle(
            color: Colors.yellow,
            fontFamily: 'CourierNew',
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clave: ${param['clave']}',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'CourierNew',
                fontSize: 12,
              ),
            ),
            SizedBox(height: 10),
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
            child: Text('CANCELAR', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('GUARDAR', style: TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.setParametro(param['clave'], valorCtrl.text.trim());
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PARÁMETROS DEL SISTEMA')),
      backgroundColor: Colors.black,
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.yellow))
          : ListView.builder(
              itemCount: _parametros.length,
              itemBuilder: (context, i) {
                final p = _parametros[i];
                return ListTile(
                  leading: Icon(Icons.settings, color: Colors.yellow),
                  title: Text(
                    p['clave'] ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'CourierNew',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor: ${p['valor'] ?? ''}',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontFamily: 'CourierNew',
                          fontSize: 12,
                        ),
                      ),
                      if (p['descripcion'] != null)
                        Text(
                          p['descripcion'] as String,
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'CourierNew',
                            fontSize: 10,
                          ),
                        ),
                    ],
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