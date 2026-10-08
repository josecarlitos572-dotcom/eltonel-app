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

    // Lista de botones según rol
    final List<Map<String, dynamic>> botones = [
      {'titulo': 'NUEVA VENTA', 'screen': VentaScreen()},
      if (isAdmin) ...[
        {'titulo': 'ENVIAR STOCK', 'screen': TransferenciaScreen()},
        {'titulo': 'GESTIÓN PERSONAL', 'screen': AdminPersonalScreen()},
        {'titulo': 'CIERRE DE CAJA', 'screen': CierreCajaScreen()},
        {'titulo': 'MI RENTABILIDAD', 'screen': RentabilidadScreen()},
        {'titulo': 'CUENTAS X COBRAR', 'screen': CxcScreen()},
        {'titulo': 'REGISTRAR GASTO', 'screen': CompraScreen()},
        {'titulo': 'MANTENIMIENTO', 'screen': MantenimientoMenuScreen()},
      ],
      {'titulo': 'RECIBIR INICIO JORNADA', 'screen': RecepcionTrasladosScreen()},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('MENÚ PRINCIPAL'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            // GRID DE BOTONES
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  ...botones.map((b) => _btnCuadrado(
                    context,
                    b['titulo'] as String,
                    b['screen'] as Widget,
                  )),
                  // Botón SALIR al final
                  _btnSalir(context, auth),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Botón cuadrado con borde negro sólido
  Widget _btnCuadrado(BuildContext ctx, String titulo, Widget screen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.yellow,
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => screen),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'CourierNew',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botón SALIR cuadrado
  Widget _btnSalir(BuildContext ctx, AuthService auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red,
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            auth.logout();
            Navigator.pushReplacementNamed(ctx, '/');
          },
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                'SALIR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CourierNew',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}