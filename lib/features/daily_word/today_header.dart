import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/streak_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/streak_colors.dart';
import '../../core/utils/date_utils.dart';

/// Top of the Today screen: greeting, streak chip, and a progress card with
/// today's progress ring and this week's activity.
class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.greeting,
    required this.firstName,
    required this.streak,
    required this.readCount,
    required this.total,
    required this.rawActivityLog,
    required this.today,
    this.isWeekendReview = false,
  });

  final String greeting;
  final String firstName;
  final int streak;
  final int readCount;
  final int total;
  final Map<String, dynamic> rawActivityLog;
  final DateTime today;
  final bool isWeekendReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StreakChip(streak: streak),
          ],
        ),
        const SizedBox(height: 16),
        _ProgressCard(
          readCount: readCount,
          total: total,
          rawActivityLog: rawActivityLog,
          today: today,
          isWeekendReview: isWeekendReview,
        ),
      ],
    );
  }
}

/// Flame plus the current streak, counting up when it changes.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    final color = active ? context.colors.caution : context.colors.textMuted;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: streak == 1 ? '1 day streak' : '$streak day streak',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 18, color: color),
              const SizedBox(width: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(end: streak.toDouble()),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  '${value.round()}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.readCount,
    required this.total,
    required this.rawActivityLog,
    required this.today,
    required this.isWeekendReview,
  });

  final int readCount;
  final int total;
  final Map<String, dynamic> rawActivityLog;
  final DateTime today;
  final bool isWeekendReview;

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && readCount >= total;
    final remaining = math.max(0, total - readCount);
    final title = done
        ? (isWeekendReview ? 'Week reviewed' : 'Day complete')
        : '$readCount of $total ${isWeekendReview ? 'reviewed' : 'words read'}';
    final subtitle = isWeekendReview
        ? (done
              ? 'Nice work. New words on Monday.'
              : 'Weekend review · words from this week')
        : done
        ? 'Perfect day. New words tomorrow.'
        : remaining == 1
        ? '1 more for a perfect day'
        : '$remaining more for a perfect day';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(value: readCount, total: total),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WeekStrip(rawActivityLog: rawActivityLog, today: today),
        ],
      ),
    );
  }
}

/// Circular progress for today's words, animating as words are read.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.total,
    this.size = 52,
  });

  final int value;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final target = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    final done = total > 0 && value >= total;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$value of $total read',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                track: context.colors.surfaceSunken,
                fill: context.colors.brand,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: done
                      ? Icon(
                          Icons.star_rounded,
                          key: const ValueKey('star'),
                          color: context.colors.brand,
                          size: 24,
                        )
                      : Text(
                          '$value/$total',
                          key: ValueKey(value),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = fill;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

/// Monday-to-Sunday dots for the current week, coloured like the heatmap.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.rawActivityLog,
    required this.today,
  });

  final Map<String, dynamic> rawActivityLog;
  final DateTime today;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final day = DateTime(today.year, today.month, today.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          _dayDot(context, monday.add(Duration(days: i)), i, day),
      ],
    );
  }

  Widget _dayDot(BuildContext context, DateTime date, int i, DateTime today) {
    final id = DateUtilsGradual.localDateId(date);
    final isToday = date == today;
    final isFuture = date.isAfter(today);
    final cell = isFuture
        ? HeatmapCell.none
        : StreakEngine.heatmapCell(rawActivityLog, id, 3);
    final active = cell != HeatmapCell.none;
    final fill = active
        ? StreakColors.colorFor(cell, context.colors)
        : Colors.transparent;
    final labelColor = isToday
        ? context.colors.textPrimary
        : context.colors.textMuted;

    return Semantics(
      label: '$id ${StreakColors.labelFor(cell)}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _letters[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isToday
                      ? context.colors.brand
                      : active
                      ? Colors.transparent
                      : context.colors.border.withValues(
                          alpha: isFuture ? 0.5 : 1,
                        ),
                  width: isToday ? 2 : 1.5,
                ),
              ),
              child: cell == HeatmapCell.perfect
                  ? Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: context.colors.onBrand,
                    )
                  : active
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      // Partial days use a pale fill, so the check needs the brand colour.
                      color: cell == HeatmapCell.partial
                          ? context.colors.brand
                          : context.colors.onBrand,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
