import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A soft wash of colour across the top of the screen: brand green from the
/// top left, a hint of blue from the top right, fading into the plain
/// background. Paints nothing below [height].
class AmbientGlowLayer extends StatelessWidget {
  const AmbientGlowLayer({super.key, this.height = 460});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.7, -1.1),
                      radius: 1.15,
                      colors: [c.glowPrimary, c.glowPrimary.withValues(alpha: 0)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1.0, -0.9),
                      radius: 0.9,
                      colors: [c.glowSecondary, c.glowSecondary.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] drawn over an [AmbientGlowLayer].
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key, required this.child, this.height = 460});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: AmbientGlowLayer(height: height)),
        child,
      ],
    );
  }
}
