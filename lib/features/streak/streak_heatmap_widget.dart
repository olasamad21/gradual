import 'package:flutter/material.dart';
import '../../core/services/streak_engine.dart';

class StreakHeatmapWidget extends StatelessWidget {
  const StreakHeatmapWidget({
    super.key,
    required this.rawActivityLog,
    required this.liveStreak,
    required this.today,
  });

  final Map<String, dynamic> rawActivityLog;
  final int liveStreak;
  final DateTime today;

  String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Color _colorForCell(HeatmapCell cell) {
    switch (cell) {
      case HeatmapCell.none: return const Color(0xFFEAECEF);
      case HeatmapCell.partial: return const Color(0xFFC8E6C9);
      case HeatmapCell.perfect: return const Color(0xFF388E3C);
      case HeatmapCell.quizExcellent: return const Color(0xFF22C55E);
      case HeatmapCell.quizGood: return const Color(0xFFF59E0B);
      case HeatmapCell.quizFair: return const Color(0xFFF97316);
      case HeatmapCell.quizFailed: return const Color(0xFFEF4444);
    }
  }

  String _labelForCell(HeatmapCell cell) {
    switch (cell) {
      case HeatmapCell.none: return 'None';
      case HeatmapCell.partial: return 'Partial';
      case HeatmapCell.perfect: return 'Perfect';
      case HeatmapCell.quizExcellent: return 'Excellent';
      case HeatmapCell.quizGood: return 'Good';
      case HeatmapCell.quizFair: return 'Fair';
      case HeatmapCell.quizFailed: return 'Failed';
    }
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
        final int columnCount = (maxWidth / (boxSize + spacing)).floor();
        final int totalDaysToShow = columnCount * 2;

        final dates = List.generate(
          totalDaysToShow,
          (i) => DateTime(today.year, today.month, today.day - (totalDaysToShow - 1 - i)),
        );

        final streakLabel = liveStreak == 0
            ? 'No active streak'
            : liveStreak == 1
                ? '1 day streak'
                : '$liveStreak day streak';

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
                _legendDot(const Color(0xFFC8E6C9), 'Partial'),
                _legendDot(const Color(0xFF388E3C), 'Perfect', hasStar: true),
                _legendDot(const Color(0xFFF97316), 'Fair'),
                _legendDot(const Color(0xFFF59E0B), 'Good'),
                _legendDot(const Color(0xFF22C55E), 'Excellent'),
                _legendDot(const Color(0xFFEF4444), 'Failed'),
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
                
                final cellState = StreakEngine.heatmapCell(rawActivityLog, key, 3);
                final color = _colorForCell(cellState);
                final isToday = key == _formatDateKey(today);
                
                final labelStr = '$key — ${_labelForCell(cellState)}';

                return Tooltip(
                  message: labelStr,
                  child: Semantics(
                    label: labelStr,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isToday
                              ? const Color(0xFF388E3C)
                              : const Color(0x0D000000), // Colors.black.withValues(alpha: 0.05)
                          width: isToday ? 1.5 : 1,
                        ),
                      ),
                      child: cellState == HeatmapCell.perfect 
                          ? const Icon(Icons.star_rounded, size: 10, color: Colors.white) 
                          : null,
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

  Widget _legendDot(Color color, String label, {bool hasStar = false}) {
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
              color: const Color(0x14000000), // Colors.black.withValues(alpha: 0.08)
              width: 1,
            ),
          ),
          child: hasStar
              ? const Icon(Icons.star_rounded, size: 6, color: Colors.white)
              : null,
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
}
