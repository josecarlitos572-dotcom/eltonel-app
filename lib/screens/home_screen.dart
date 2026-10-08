import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'venta_screen.dart';
import 'transferencia_screen.dart';
import 'recepcion_traslados_screen.dart';
import 'cierre_caja_screen.dart';
import 'rentabilidad_screen.dart';
import 'cxc_screen.dart';
import 'admin_personal_screen.dart';
import 'compra_screen.dart';
import 'mantenimiento/mantenimiento_menu_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    bool isAdmin = auth.currentUser?['rol'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('MENÚ PRINCIPAL'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isAdmin)
              Padding(
                padding: EdgeInsets.fromLTRB(15, 15, 15, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MantenimientoMenuScreen(),
                      ),
                    ),
                    icon: Icon(Icons.build, color: Colors.black, size: 32),
                    label: Text(
                      'MANTENIMIENTO',
                      style: TextStyle(
                        fontFamily: 'CourierNew',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(15),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _btn(context, 'NUEVA VENTA', VentaScreen()),
                if (isAdmin) ...[
                  _btn(context, 'ENVIAR STOCK', TransferenciaScreen()),
                  _btn(context, 'GESTIÓN PERSONAL', AdminPersonalScreen()),
                  _btn(context, 'CIERRE DE CAJA', CierreCajaScreen()),
                  _btn(context, 'MI RENTABILIDAD', RentabilidadScreen()),
                  _btn(context, 'CUENTAS X COBRAR', CxcScreen()),
                  _btn(context, 'REGISTRAR GASTO', CompraScreen()),
                ],
                _btn(context, 'RECIBIR INICIO JORNADA', RecepcionTrasladosScreen()),
                ElevatedButton(
                  onPressed: () {
                    auth.logout();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  child: Text(
                    'SALIR',
                    style: TextStyle(fontFamily: 'CourierNew', fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, String title, Widget screen) {
    return ElevatedButton(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'CourierNew', fontSize: 14),
      ),
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}