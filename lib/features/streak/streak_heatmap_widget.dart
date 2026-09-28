import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';

class StreakHeatmapWidget extends StatelessWidget {
  const StreakHeatmapWidget({
    super.key,
    required this.activityLog,
    required this.liveStreak,
    this.daysToShow = 365,
  });

  final ActivityLog activityLog;
  final int liveStreak;
  final int daysToShow;

  String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Color _colorForDate(DateTime date, ActivityLogEntry? entry) {
    if (entry != null) {
      if (entry.isLegacyEntry) return WeeklyScoreTier.legacy.color;
      if (entry.isWeeklyQuiz) return entry.tier.color;
    }

    if (date.weekday != DateTime.saturday) {
      return const Color(0xFFEAECEF);
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAfter(todayOnly)) {
      return const Color(0xFFEAECEF);
    }

    return WeeklyScoreTier.missed.color;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double boxSize = 14.0;
        const double spacing = 4.0;
        final double maxWidth = constraints.maxWidth == double.infinity
            ? 300
            : constraints.maxWidth;
        final int columnCount =
            (maxWidth / (boxSize + spacing)).floor();
        final int totalDaysToShow = columnCount * 2;

        final today = DateTime.now();
        final dates = List.generate(
          totalDaysToShow,
          (i) => today.subtract(Duration(days: i)),
        );

        final streakLabel = liveStreak == 0
            ? 'No active streak'
            : liveStreak == 1
                ? '1 week streak 🔥'
                : '$liveStreak week streak 🔥';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 16,
                      color: liveStreak > 0
                          ? Colors.orange
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      streakLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: liveStreak > 0
                            ? Colors.orange
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _legendDot(const Color(0xFFEAECEF), 'None'),
                _legendDot(WeeklyScoreTier.missed.color, 'Missed'),
                _legendDot(WeeklyScoreTier.fair.color, 'Fair'),
                _legendDot(WeeklyScoreTier.good.color, 'Good'),
                _legendDot(WeeklyScoreTier.excellent.color, 'Excellent'),
                _legendDot(WeeklyScoreTier.failed.color, 'Failed'),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemCount: totalDaysToShow,
              itemBuilder: (context, index) {
                final date = dates[index];
                final key = _formatDateKey(date);
                final entry = activityLog[key];
                final color = _colorForDate(date, entry);
                final isToday = key == _formatDateKey(today);
                return Tooltip(
                  message: _tooltipFor(date, entry),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFF388E3C)
                            : Colors.black.withOpacity(0.05),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _tooltipFor(DateTime date, ActivityLogEntry? entry) {
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final dayLabel = date.weekday == DateTime.saturday ? 'Saturday' : '';

    if (entry == null) {
      if (date.weekday == DateTime.saturday) {
        final today = DateTime.now();
        final dateOnly = DateTime(date.year, date.month, date.day);
        final todayOnly = DateTime(today.year, today.month, today.day);
        if (dateOnly.isBefore(todayOnly) || dateOnly == todayOnly) {
          return '$dateStr — Missed weekly quiz';
        }
      }
      return '$dateStr — No quiz';
    }

    if (entry.isLegacyEntry) {
      return '$dateStr — Legacy activity';
    }

    if (entry.isWeeklyQuiz) {
      final prefix = dayLabel.isNotEmpty ? '$dateStr ($dayLabel)' : dateStr;
      return '$prefix — ${entry.tier.label}: ${entry.score}/${entry.totalQuestions}';
    }

    return '$dateStr — No activity';
  }
}
