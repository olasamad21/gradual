import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/services/streak_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_rules.dart';

class StreakHeatmapWidget extends StatelessWidget {
  const StreakHeatmapWidget({
    super.key,
    required this.rawActivityLog,
    required this.liveStreak,
  });

  final Map<String, dynamic> rawActivityLog;
  final int liveStreak;

  String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // We want 12 weeks of columns.
    const int weeks = 12;
    const int totalDays = weeks * 7;
    
    // We want the right-most column to include today.
    // GitHub style usually aligns rows to days of the week.
    // Let's find out what day of the week today is.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Let's say row 0 is Sunday, row 6 is Saturday.
    // today.weekday is 1 (Monday) to 7 (Sunday).
    // Let's make Sunday = 0.
    final int todayIndex = today.weekday % 7; 
    
    // The very last cell in the bottom right (row 6) would be Saturday.
    // If today is Wednesday (3), then the last Saturday is today + (6 - 3) = today + 3 days.
    // We want our grid to end exactly on the week containing today.
    final DateTime lastDateInGrid = DateTime(today.year, today.month, today.day + (6 - todayIndex));
    
    // So the very first date in the grid (top left, row 0, col 0) is:
    // lastDateInGrid - (totalDays - 1)
    // Wait, let's use the requested approach: DateTime(y, m, d - i).
    final DateTime firstDateInGrid = DateTime(lastDateInGrid.year, lastDateInGrid.month, lastDateInGrid.day - (totalDays - 1));

    final countedDates = StreakEngine.countedDays(rawActivityLog);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Activity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: liveStreak > 0
                      ? Colors.orange
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  liveStreak == 0 ? 'No active streak' : (liveStreak == 1 ? '1 day streak' : '$liveStreak day streak'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: liveStreak > 0
                        ? Colors.orange
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Heatmap Grid
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // Auto-scroll to the right where today is
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 0; i < 7; i++)
                    Container(
                      height: 18, // matches cell height + spacing roughly
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _dayLabel(i),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              // Grid columns
              for (int w = 0; w < weeks; w++) ...[
                Column(
                  children: [
                    for (int d = 0; d < 7; d++) ...[
                      _buildCell(
                        context,
                        DateTime(firstDateInGrid.year, firstDateInGrid.month, firstDateInGrid.day + (w * 7) + d),
                        today,
                        countedDates,
                      ),
                      if (d < 6) const SizedBox(height: 4),
                    ]
                  ],
                ),
                if (w < weeks - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  String _dayLabel(int index) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    // Only show Mon, Wed, Fri for cleaner look, or all. 
    if (index == 1 || index == 3 || index == 5) return labels[index];
    return '';
  }

  Widget _buildCell(BuildContext context, DateTime date, DateTime today, Set<String> countedDates) {
    final isFuture = date.isAfter(today);
    if (isFuture) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final dateKey = _formatDateKey(date);
    final isCounted = countedDates.contains(dateKey);
    final isPerfect = StreakEngine.isPerfectDay(rawActivityLog, dateKey, AppRules.conceptsPerDay);
    
    // Check if there is a quiz score for this day
    final entry = rawActivityLog[dateKey] as Map<String, dynamic>?;
    final hasQuiz = entry != null && entry.containsKey('quiz_score');
    
    // Cell states: none, partial, perfect, quiz
    Color cellColor = const Color(0xFFE5E7EB);
    Widget? icon;
    
    if (hasQuiz) {
      cellColor = Colors.purple.shade400; // Quiz color
    } else if (isPerfect) {
      cellColor = AppTheme.primaryColor;
      icon = const Icon(Icons.star_rounded, size: 10, color: Colors.white);
    } else if (isCounted) {
      cellColor = AppTheme.primaryColor.withValues(alpha: 0.4);
    }
    
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: Colors.black87, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'Less',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        _legendItem(const Color(0xFFE5E7EB)),
        const SizedBox(width: 4),
        _legendItem(AppTheme.primaryColor.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        _legendItem(AppTheme.primaryColor, icon: const Icon(Icons.star_rounded, size: 8, color: Colors.white)),
        const SizedBox(width: 4),
        _legendItem(Colors.purple.shade400),
        const SizedBox(width: 6),
        const Text(
          'More',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
  
  Widget _legendItem(Color color, {Widget? icon}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
