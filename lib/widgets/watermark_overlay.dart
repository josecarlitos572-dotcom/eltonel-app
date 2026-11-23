// Archivo: lib/widgets/watermark_overlay.dart
// Propósito: Sello de agua visible sobre fondos oscuros en la app "El Tonel".

import 'package:flutter/material.dart'; // 1. Librería base de Flutter.

class WatermarkOverlay extends StatelessWidget { // 2. Widget sin estado (solo dibuja).
  final String text; // 3. Texto del sello de agua.
  final double opacity; // 4. Transparencia (0.0 invisible, 1.0 sólido).
  final double fontSize; // 5. Tamaño de la fuente del texto.

  const WatermarkOverlay({ // 6. Constructor const para optimizar el renderizado.
    Key? key, // 7. Llave opcional (buena práctica de Flutter).
    this.text = 'El Tonel', // 8. Texto por defecto si no se especifica.
    this.opacity = 0.10, // 9. Opacidad 0.10: visible pero sin estorbar.
    this.fontSize = 45.0, // 10. Tamaño grande para cubrir el fondo.
  }) : super(key: key); // 11. Llama al constructor de StatelessWidget.

  @override
  Widget build(BuildContext context) { // 12. Método que dibuja el widget.
    return Positioned.fill( // 13. Ocupa TODO el espacio del Stack.
      child: IgnorePointer( // 14. CLAVE: los toques atraviesan el sello y llegan a los botones.
        child: Opacity( // 15. Aplica la transparencia configurada.
          opacity: opacity,
          child: Center( // 16. Centra el sello en pantalla.
            child: Transform.rotate( // 17. Rotación diagonal clásica de marca de agua.
              angle: -0.4, // 18. Aproximadamente -23 grados.
              child: Text(
                text, // 19. El texto del sello.
                style: TextStyle(
                  fontSize: fontSize, // 20. Tamaño de fuente.
                  fontWeight: FontWeight.bold, // 21. Negrita para que se note.
                  color: Colors.white, // 22. ¡BLANCO! Ahora sí se ve sobre fondo negro.
                  letterSpacing: 3.0, // 23. Espaciado entre letras, estilo elegante.
                ),
                textAlign: TextAlign.center, // 24. Texto centrado.
              ),
            ),
          ),
        ),
      ),
    );
  }
}