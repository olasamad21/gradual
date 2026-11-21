import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/streak_engine.dart';
import '../../core/theme/streak_colors.dart';

class StreakBox extends StatelessWidget {
  const StreakBox({
    super.key,
    required this.cell,
    this.size = 14.0,
    this.isToday = false,
    this.animate = false,
  });

  final HeatmapCell cell;
  final double size;
  final bool isToday;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = StreakColors.colorFor(cell, context.colors);
    
    Widget box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * (3.0 / 14.0)),
        border: Border.all(
          color: isToday
              ? context.colors.brand
              : context.colors.shadow.withValues(alpha: 0.05),
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: cell == HeatmapCell.perfect
          ? Icon(Icons.star_rounded, size: size * (10.0 / 14.0), color: context.colors.onBrand)
          : null,
    );

    if (animate) {
      // Future animation support
    }

    return box;
  }
}
