import 'package:flutter/material.dart';

/// Subtle dot grid painted behind screen content.
class DotPatternPainter extends CustomPainter {
  DotPatternPainter({required this.color});

  final Color color;

  static const double _spacing = 24.0;
  static const double _radius = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double i = 0; i < size.width; i += _spacing) {
      for (double j = 0; j < size.height; j += _spacing) {
        canvas.drawCircle(Offset(i, j), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) => oldDelegate.color != color;
}
