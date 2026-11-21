import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The Gradual brand mark: a dot that grows into two rising bars, each step
/// more solid than the last. It stands for small daily steps that add up.
///
/// The mark is drawn in code so the in-app logo, launcher icons and splash
/// images all come from this one source (see tool/brand/).
class GradualMarkPainter extends CustomPainter {
  const GradualMarkPainter({required this.color});

  final Color color;

  /// Bars in a 100 x 100 design box: (left, top, opacity). All share width
  /// and bottom edge.
  static const _bars = [(14.0, 68.0, 0.55), (41.0, 44.0, 0.78), (68.0, 14.0, 1.0)];
  static const _barWidth = 18.0;
  static const _bottom = 86.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100.0;
    final dx = (size.width - 100.0 * scale) / 2;
    final dy = (size.height - 100.0 * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    for (final (left, top, opacity) in _bars) {
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * opacity)
        ..isAntiAlias = true;
      canvas.drawRRect(
        RRect.fromLTRBR(left, top, left + _barWidth, _bottom, const Radius.circular(_barWidth / 2)),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GradualMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The bare mark in a single colour.
class GradualMark extends StatelessWidget {
  const GradualMark({super.key, this.size = 48, this.color});

  final double size;

  /// Defaults to the brand colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: GradualMarkPainter(color: color ?? context.colors.brand)),
    );
  }
}

/// Gradient used behind the mark on the app icon and logo tile.
const gradualIconGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32), Color(0xFF1B5E20)],
  stops: [0.0, 0.55, 1.0],
);

/// The app icon as a widget: the white mark on a green gradient tile.
class GradualLogoTile extends StatelessWidget {
  const GradualLogoTile({super.key, this.size = 80, this.showShadow = true});

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradualIconGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: GradualMark(size: size * 0.62, color: Colors.white),
    );
  }
}
