import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';

class PuntosVentaScreen extends StatefulWidget {
  @override
  _PuntosVentaScreenState createState() => _PuntosVentaScreenState();
}

class _PuntosVentaScreenState extends State<PuntosVentaScreen> {
  List<Map<String, dynamic>> _puntos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final data = await db.consultar('puntos_venta', orderBy: 'id ASC');
    setState(() {
      _puntos = data;
      _cargando = false;
    });
  }

  Future<void> _editar({Map<String, dynamic>? punto}) async {
    final nombreCtrl = TextEditingController(text: punto?['nombre'] ?? '');
    final codigoCtrl = TextEditingController(text: punto?['codigo'] ?? '');
    final direccionCtrl = TextEditingController(text: punto?['direccion'] ?? '');
    final iniCtrl = TextEditingController(text: punto?['ini_vta'] ?? '03:00');
    final finCtrl = TextEditingController(text: punto?['fin_vta'] ?? '11:00');
    String diaDescanso = punto?['dia_descanso'] ?? 'dom';
    final esEdicion = punto != null;

    final dias = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];

    if (!mounted) return;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String diaSel = diaDescanso;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: Text(
                esEdicion ? 'EDITAR PUNTO' : 'NUEVO PUNTO',
                style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew', fontSize: 15),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codigoCtrl,
                      decoration: InputDecoration(labelText: 'Código (ej: SR1)'),
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: nombreCtrl,
                      decoration: InputDecoration(labelText: 'Nombre'),
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: direccionCtrl,
                      decoration: InputDecoration(labelText: 'Dirección (opcional)'),
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: iniCtrl,
                      decoration: InputDecoration(labelText: 'Hora inicio (HH:MM)'),
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: finCtrl,
                      decoration: InputDecoration(labelText: 'Hora fin (HH:MM)'),
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: diaSel,
                      dropdownColor: Colors.black,
                      style: TextStyle(color: Colors.white, fontFamily: 'CourierNew'),
                      decoration: InputDecoration(labelText: 'Día de descanso'),
                      items: dias.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d.toUpperCase(),
                            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')));
                      }).toList(),
                      onChanged: (v) => setStateDialog(() => diaSel = v ?? 'dom'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('CANCELAR', style: TextStyle(color: Colors.white))),
                TextButton(
                    onPressed: () {
                      diaDescanso = diaSel;
                      Navigator.pop(ctx, true);
                    },
                    child: Text('GUARDAR', style: TextStyle(color: Colors.yellow))),
              ],
            );
          },
        );
      },
    );

    if (resultado == true) {
      if (codigoCtrl.text.trim().isEmpty || nombreCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código y nombre obligatorios'), backgroundColor: Colors.red),
        );
        return;
      }
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      final Map<String, dynamic> data = {
        'nombre': nombreCtrl.text.trim(),
        'codigo': codigoCtrl.text.trim().toUpperCase(),
        'direccion': direccionCtrl.text.trim(),
        'ini_vta': iniCtrl.text.trim(),
        'fin_vta': finCtrl.text.trim(),
        'dia_descanso': diaDescanso,
        'activo': 1,
      };
      try {
        if (esEdicion) {
          data['id'] = punto['id'];
          await db.actualizar('puntos_venta', data);
        } else {
          await db.insertar('puntos_venta', data);
        }
        _cargar();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _desactivar(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('¿Desactivar?',
            style: TextStyle(color: Colors.yellow, fontFamily: 'CourierNew')),
        content: Text('Se desactivará "$nombre"',
            style: TextStyle(color: Colors.white, fontFamily: 'CourierNew')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NO', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('SÍ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      final db = Provider.of<DatabaseHelper>(context, listen: false);
      await db.actualizar('puntos_venta', {'id': id, 'activo': 0});
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PUNTOS DE VENTA'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.yellow,
        onPressed: () => _editar(),
        child: Icon(Icons.add, color: Colors.black),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.yellow))
          : ListView.builder(
              itemCount: _puntos.length,
              itemBuilder: (context, i) {
                final p = _puntos[i];
                final activo = (p['activo'] ?? 1) == 1;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: activo ? Colors.yellow : Colors.grey,
                    child: Text(
                      p['codigo'] ?? '?',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  title: Text(p['nombre'] ?? '',
                      style: TextStyle(
                        color: activo ? Colors.white : Colors.white38,
                        fontFamily: 'CourierNew',
                        fontSize: 13,
                      )),
                  subtitle: Text(
                    '${p['ini_vta'] ?? '--'} a ${p['fin_vta'] ?? '--'} · Descansa: ${(p['dia_descanso'] ?? '--').toString().toUpperCase()}',
                    style: TextStyle(color: Colors.white54, fontFamily: 'CourierNew', fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: Icon(Icons.edit, color: Colors.yellow),
                          onPressed: () => _editar(punto: p)),
                      IconButton(
                          icon: Icon(Icons.power_settings_new, color: Colors.red),
                          onPressed: () => _desactivar(p['id'] as int, p['nombre'] ?? '')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}