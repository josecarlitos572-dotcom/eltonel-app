import 'package:flutter/material.dart';

class WatermarkOverlay extends StatelessWidget {
  final String text;
  final double opacity;
  final double fontSize;

  const WatermarkOverlay({
    Key? key,
    this.text = 'El Tonel',
    this.opacity = 0.08,
    this.fontSize = 45.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Center(
            child: Transform.rotate(
              angle: -0.4,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 3.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}