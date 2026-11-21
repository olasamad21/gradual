import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class RewardBurst extends StatefulWidget {
  const RewardBurst({
    super.key,
    required this.child,
    this.animate = true,
  });

  final Widget child;
  final bool animate;

  @override
  State<RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<RewardBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(RewardBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.forward(from: 0.0);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final shouldAnimate = widget.animate && !disableAnimations;

    if (!shouldAnimate) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _BurstPainter(
            progress: _animation.value,
            colors: [context.colors.brand, context.colors.warning, context.colors.infoStrong],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required List<Color> colors}) : _colors = colors;

  final double progress;

  /// Brand green, gold and blue particles.
  final List<Color> _colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    const particleCount = 24;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * 2 * math.pi) / particleCount;
      final maxDist = 55.0 + (i % 4) * 12.0;
      final dist = progress * maxDist;
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;

      final color = _colors[i % _colors.length].withValues(alpha: opacity);
      final paint = Paint()..color = color;
      final radius = 2.5 + (i % 3) * 0.8;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.progress != progress;
}
