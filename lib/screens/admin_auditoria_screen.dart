import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';

class AdminAuditoriaScreen extends StatefulWidget {
  @override
  _AdminAuditoriaScreenState createState() => _AdminAuditoriaScreenState();
}

class _AdminAuditoriaScreenState extends State<AdminAuditoriaScreen> {
  List<Map<String, dynamic>> _registros = [];
  bool _cargando = true;
  String _filtroAccion = 'TODAS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = Provider.of<DatabaseHelper>(context, listen: false);
    final data = await db.consultar('auditoria_cambios',
        orderBy: 'id DESC');

    if (mounted) {
      setState(() {
        _registros = data;
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtroAccion == 'TODAS') return _registros;
    return _registros
        .where((r) => (r['accion'] ?? '').toString().contains(_filtroAccion))
        .toList();
  }

  Color _colorAccion(String accion) {
    if (accion.contains('CIERRE') || accion.contains('DESMEDRO')) {
      return Colors.red;
    }
    if (accion.contains('VENTA') || accion.contains('ABONO')) return Colors.green;
    if (accion.contains('TRASLADO') || accion.contains('BATCH')) {
      return Colors.orange;
    }
    if (accion.contains('REQUERIMIENTO')) return Colors.blue;
    return Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text('AUDITORÍA'), backgroundColor: Colors.black),
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: Text('AUDITORÍA (${filtrados.length})'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Color(0xFF1A1A1A),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipFiltro('TODAS'),
                  _chipFiltro('VENTA'),
                  _chipFiltro('ABONO'),
                  _chipFiltro('CIERRE'),
                  _chipFiltro('BATCH'),
                  _chipFiltro('REQUERIMIENTO'),
                  _chipFiltro('TRASLADO'),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Text('Sin registros',
                        style: TextStyle(
                            color: Colors.white54, fontFamily: 'CourierNew')),
                  )
                : ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (ctx, i) {
                      final r = filtrados[i];
                      final accion = (r['accion'] ?? '').toString();
                      final color = _colorAccion(accion);
                      final fecha = (r['fecha'] ?? '').toString();
                      final fechaCorta =
                          fecha.length > 16 ? fecha.substring(0, 16) : fecha;

                      return Card(
                        color: Color(0xFF1A1A1A),
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: color,
                            child: Icon(Icons.history,
                                color: Colors.black, size: 16),
                          ),
                          title: Text(accion,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'CourierNew',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['usuario_nombre'] ?? ''} · $fechaCorta',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontFamily: 'CourierNew',
                                    fontSize: 9),
                              ),
                              if ((r['datos_nuevos'] ?? '').toString().isNotEmpty)
                                Text(
                                  (r['datos_nuevos'] ?? '').toString(),
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'CourierNew',
                                      fontSize: 9),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(String valor) {
    final activo = _filtroAccion == valor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        label: Text(valor,
            style: TextStyle(fontFamily: 'CourierNew', fontSize: 10)),
        selected: activo,
        onSelected: (v) => setState(() => _filtroAccion = valor),
        selectedColor: Colors.yellow,
        backgroundColor: Colors.grey[900],
        labelStyle: TextStyle(color: activo ? Colors.black : Colors.white),
      ),
    );
  }
}