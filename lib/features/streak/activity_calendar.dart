import 'package:flutter/material.dart';

import '../../core/config/app_rules.dart';
import '../../core/services/streak_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/streak_colors.dart';
import '../../core/utils/date_utils.dart';

/// GitHub-style activity grid: one column per week (Monday at the top),
/// month labels along the top, newest week on the right.
class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({
    super.key,
    required this.rawActivityLog,
    required this.today,
    this.weeks = 18,
  });

  final Map<String, dynamic> rawActivityLog;
  final DateTime today;
  final int weeks;

  static const double _cell = 14;
  static const double _gap = 4;
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _dayLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final day = DateTime(today.year, today.month, today.day);
    final thisMonday = day.subtract(Duration(days: day.weekday - 1));
    final firstMonday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * (weeks - 1));

    final columns = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      final monday = DateTime(firstMonday.year, firstMonday.month, firstMonday.day + 7 * w);
      final previousMonday = DateTime(monday.year, monday.month, monday.day - 7);
      final showMonth = w == 0 || monday.month != previousMonday.month;
      columns.add(Padding(
        padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : _gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              width: _cell,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: 40,
                child: Text(
                  showMonth ? _months[monday.month - 1] : '',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textMuted),
                ),
              ),
            ),
            for (var d = 0; d < 7; d++) ...[
              _cellFor(context, DateTime(monday.year, monday.month, monday.day + d), day),
              if (d < 6) const SizedBox(height: _gap),
            ],
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var d = 0; d < 7; d++)
                    SizedBox(
                      height: _cell + (d < 6 ? _gap : 0),
                      child: Text(_dayLabels[d], style: TextStyle(fontSize: 9, color: c.textMuted)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legend(context, HeatmapCell.partial, 'Read'),
            _legend(context, HeatmapCell.perfect, 'Perfect day'),
            _legend(context, HeatmapCell.quizExcellent, 'Quiz'),
          ],
        ),
      ],
    );
  }

  Widget _cellFor(BuildContext context, DateTime date, DateTime today) {
    final c = context.colors;
    final isFuture = date.isAfter(today);
    final id = DateUtilsGradual.localDateId(date);
    final cell = isFuture ? HeatmapCell.none : StreakEngine.heatmapCell(rawActivityLog, id, AppRules.conceptsPerDay);
    final isToday = date == today;
    final label = '$id ${StreakColors.labelFor(cell)}';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: _cell,
          height: _cell,
          decoration: BoxDecoration(
            color: isFuture ? Colors.transparent : StreakColors.colorFor(cell, c),
            borderRadius: BorderRadius.circular(4),
            border: isToday
                ? Border.all(color: c.brand, width: 1.5)
                : isFuture
                    ? Border.all(color: c.border.withValues(alpha: 0.6))
                    : null,
          ),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, HeatmapCell cell, String label) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: StreakColors.colorFor(cell, c), borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: c.textTertiary)),
      ],
    );
  }
}
