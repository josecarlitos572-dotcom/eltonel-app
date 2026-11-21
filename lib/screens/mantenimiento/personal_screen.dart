import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_helper.dart';
import '../../services/password_service.dart';

class PersonalScreen extends StatefulWidget {
  @override
  _PersonalScreenState createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  List<Map<String, dynamic>> _personal = [];
  List<Map<String, dynamic>> _puntos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final db = context.read<DatabaseHelper>();
    _personal = await db.consultar('personal', orderBy: 'id ASC');
    _puntos = await db.getPuntosVenta();
    if (mounted) setState(() => _cargando = false);
  }

  void _mostrarFormulario({Map<String, dynamic>? usuario}) {
    final esEdicion = usuario != null;
    final dniCtrl = TextEditingController(text: usuario?['dni'] ?? '');
    final nomCtrl = TextEditingController(text: usuario?['nombres'] ?? '');
    final apeCtrl = TextEditingController(text: usuario?['apellidos'] ?? '');
    final fonoCtrl = TextEditingController(text: usuario?['fono'] ?? '');
    final passCtrl = TextEditingController();
    String rol = usuario?['rol'] ?? 'VENDEDOR';
    int? pvId = usuario?['punto_venta_id'] as int?;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(esEdicion ? 'EDITAR USUARIO' : 'NUEVO USUARIO', style: const TextStyle(color: Colors.yellow)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: dniCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'DNI', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                const SizedBox(height: 8),
                TextField(controller: nomCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nombres', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                const SizedBox(height: 8),
                TextField(controller: apeCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Apellidos', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                const SizedBox(height: 8),
                TextField(controller: fonoCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Teléfono', labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)))),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: esEdicion ? 'Nueva contraseña (vacío = no cambiar)' : 'Contraseña',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: rol,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Rol', labelStyle: TextStyle(color: Colors.white70)),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'VENDEDOR', child: Text('VENDEDOR', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'CAJERO', child: Text('CAJERO', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setD(() => rol = v ?? 'VENDEDOR'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: pvId,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Punto de Venta', labelStyle: TextStyle(color: Colors.white70)),
                  items: _puntos.map<DropdownMenuItem<int>>((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['codigo']} - ${p['nombre']}', style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setD(() => pvId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
              onPressed: () async {
                if (dniCtrl.text.isEmpty || nomCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DNI y Nombres son obligatorios'), backgroundColor: Colors.red));
                  return;
                }
                if (!esEdicion && passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña es obligatoria para nuevos usuarios'), backgroundColor: Colors.red));
                  return;
                }

                final db = context.read<DatabaseHelper>();
                final data = {
                  'dni': dniCtrl.text.trim(),
                  'nombres': nomCtrl.text.trim(),
                  'apellidos': apeCtrl.text.trim(),
                  'fono': fonoCtrl.text.trim(),
                  'rol': rol,
                  'punto_venta_id': pvId,
                  'activo': 1,
                };

                if (passCtrl.text.isNotEmpty) {
                  data['password'] = PasswordService.hashPassword(passCtrl.text);
                  data['requiere_cambio_password'] = 1;
                }

                if (esEdicion) {
                  data['id'] = usuario!['id'];
                  await db.actualizar('personal', data);
                } else {
                  await db.insertar('personal', data);
                }
                
                Navigator.pop(ctx);
                _cargar();
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminar(int id) async {
    final db = context.read<DatabaseHelper>();
    await db.eliminar('personal', id);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(
      appBar: AppBar(title: const Text('GESTIÓN DE PERSONAL'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.yellow,
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: ListView.builder(
        itemCount: _personal.length,
        itemBuilder: (_, i) {
          final u = _personal[i];
          return Card(
            color: const Color(0xFF1A1A1A),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.yellow, child: Text(u['dni'].toString().substring(0, 2), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              title: Text('${u['nombres']} ${u['apellidos']}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('${u['rol']} - PV: ${u['punto_venta_id'] ?? 'Ninguno'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _mostrarFormulario(usuario: u)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _eliminar(u['id'] as int)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}