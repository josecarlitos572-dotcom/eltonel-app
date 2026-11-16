import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class CompraScreen extends StatefulWidget {
  @override
  _CompraScreenState createState() => _CompraScreenState();
}

class _CompraScreenState extends State<CompraScreen> {
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  int _categoriaId = 1;
  List<Map<String, dynamic>> _categorias = [];
  int tieneComprobante = 0;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final db = await dbHelper.database;
    var cats = await db.query('categorias_gasto', where: 'activo = 1');
    setState(() {
      _categorias = cats;
      if (cats.isNotEmpty) {
        _categoriaId = cats.first['id'] as int;
      }
    });
  }

  void _guardarGasto() async {
    if (_montoCtrl.text.isEmpty) return;
    
    double monto = double.tryParse(_montoCtrl.text) ?? 0;
    var catSeleccionada = _categorias.firstWhere((c) => c['id'] == _categoriaId);
    double limite = (catSeleccionada['limite_max'] as num?)?.toDouble() ?? 0.0;
    
    if (monto > limite) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LÍMITE EXCEDIDO. Máximo para ${catSeleccionada['nombre']} es S/. $limite'), backgroundColor: Colors.red)
      );
      return;
    }

    final dbHelper = Provider.of<DatabaseHelper>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    int usuarioId = auth.currentUser?['id'] as int? ?? 1;
    
    String nombreCategoria = catSeleccionada['nombre'] as String;

    await dbHelper.registrarGasto(nombreCategoria, _descCtrl.text, monto, tieneComprobante, usuarioId);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gasto Registrado Correctamente'), backgroundColor: Colors.green));
    setState(() { _montoCtrl.clear(); _descCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('REGISTRAR GASTO OPERATIVO'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButton<int>(
              value: _categoriaId,
              dropdownColor: Colors.black,
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
              items: _categorias.map<DropdownMenuItem<int>>((val) => DropdownMenuItem<int>(
                value: val['id'] as int,
                child: Text(val['nombre'] as String),
              )).toList(),
              onChanged: (val) => setState(() => _categoriaId = val!),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Descripción Detallada',
                labelStyle: TextStyle(color: Colors.white)
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _montoCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto S/.',
                labelStyle: TextStyle(color: Colors.white)
              ),
              style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿Tiene Comprobante?', style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
                Switch(
                  value: tieneComprobante == 1,
                  onChanged: (val) => setState(() => tieneComprobante = val ? 1 : 0)
                )
              ],
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _guardarGasto,
              child: Text('GUARDAR GASTO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                minimumSize: Size(double.infinity, 50)
              )
            )
          ],
        ),
      ),
    );
  }
}