// Archivo: lib/screens/home_screen.dart
// Propósito: Pantalla principal de la app "El Tonel" con marca de agua integrada.

import 'package:flutter/material.dart'; // 1. Importamos Flutter.
import '../widgets/watermark_overlay.dart'; // 2. Importamos el widget de marca de agua.

class HomeScreen extends StatelessWidget { // 3. Definimos la pantalla como StatelessWidget.
  const HomeScreen({Key? key}) : super(key: key); // 4. Constructor estándar.

  @override
  Widget build(BuildContext context) { // 5. Método que construye la interfaz.
    return Scaffold( // 6. Scaffold es la estructura base de una pantalla en Flutter.
      appBar: AppBar( // 7. Barra superior de la app.
        title: const Text('El Tonel - Inicio'), // 8. Título de la barra.
        backgroundColor: Colors.brown, // 9. Color de fondo (puedes cambiarlo).
      ),
      body: Stack( // 10. ¡AQUÍ ESTÁ LA CLAVE! Stack permite superponer capas.
        children: [ // 11. Lista de widgets que se apilan uno sobre otro.
          
          // 12. PRIMERA CAPA: Tu contenido normal de la pantalla.
          // Aquí va todo lo que normalmente tendrías (Column, ListView, etc.)
          Center( // 13. Centramos el contenido en la pantalla.
            child: Column( // 14. Column apila widgets verticalmente.
              mainAxisAlignment: MainAxisAlignment.center, // 15. Centra verticalmente.
              children: [ // 16. Lista de widgets dentro de la Column.
                const Icon( // 17. Un ícono de ejemplo.
                  Icons.restaurant_menu,
                  size: 100,
                  color: Colors.brown,
                ),
                const SizedBox(height: 20), // 18. Espacio vertical.
                const Text( // 19. Texto de ejemplo.
                  'Bienvenido a El Tonel',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10), // 20. Otro espacio vertical.
                ElevatedButton( // 21. Un botón de ejemplo.
                  onPressed: () {
                    // Aquí va la acción del botón.
                  },
                  child: const Text('Ver Menú'),
                ),
              ],
            ),
          ),

          // 22. SEGUNDA CAPA: La marca de agua (va AL FINAL para quedar encima de todo).
          const WatermarkOverlay( // 23. Llamamos al widget de marca de agua.
            text: 'El Tonel', // 24. Texto que mostrará.
            opacity: 0.08, // 25. Opacidad muy baja para que sea sutil.
            fontSize: 50.0, // 26. Tamaño grande para cubrir el fondo.
          ),
          
        ], // 27. Cierre de la lista 'children' del Stack.
      ), // 28. Cierre del widget Stack.
    ); // 29. Cierre del Scaffold.
  } // 30. Cierre del método build.
} // 31. Cierre de la clase HomeScreen.