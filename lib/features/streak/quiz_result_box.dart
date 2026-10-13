import 'package:flutter/material.dart';

import '../../core/services/streak_engine.dart';
import '../../shared/widgets/streak_box.dart';

class QuizResultBox extends StatefulWidget {
  const QuizResultBox({
    super.key,
    required this.tier,
    this.animate = true,
  });

  final String tier;
  final bool animate;

  @override
  State<QuizResultBox> createState() => _QuizResultBoxState();
}

class _QuizResultBoxState extends State<QuizResultBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  String get _normalizedTier => widget.tier.toLowerCase().trim();

  @override
  void initState() {
    super.initState();
    final tier = _normalizedTier;
    Duration duration;
    Curve curve;

    if (tier == 'excellent' || tier == 'good') {
      duration = const Duration(milliseconds: 700);
      curve = Curves.elasticOut;
    } else if (tier == 'fair') {
      duration = const Duration(milliseconds: 400);
      curve = Curves.easeOut;
    } else {
      duration = const Duration(milliseconds: 300);
      curve = Curves.easeIn;
    }

    _controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: curve,
    );

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (HeatmapCell, String) _cellAndCaption() {
    switch (_normalizedTier) {
      case 'excellent':
        return (HeatmapCell.quizExcellent, 'Excellent');
      case 'good':
        return (HeatmapCell.quizGood, 'Good');
      case 'fair':
        return (HeatmapCell.quizFair, 'Fair');
      case 'failed':
      default:
        return (HeatmapCell.quizFailed, 'Keep practicing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final (cell, caption) = _cellAndCaption();
    final isFailed = _normalizedTier == 'failed' ||
        (_normalizedTier != 'excellent' &&
            _normalizedTier != 'good' &&
            _normalizedTier != 'fair');

    Widget box = StreakBox(
      cell: cell,
      size: 36.0,
    );

    Widget animatedBox;
    if (!widget.animate || disableAnimations) {
      animatedBox = box;
    } else if (isFailed) {
      animatedBox = FadeTransition(
        opacity: _animation,
        child: box,
      );
    } else {
      animatedBox = ScaleTransition(
        scale: _animation,
        child: box,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animatedBox,
        const SizedBox(height: 8),
        Text(
          caption,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
