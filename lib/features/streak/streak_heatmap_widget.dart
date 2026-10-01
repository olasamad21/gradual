import 'package:flutter/material.dart';
import '../../core/services/streak_engine.dart';
import '../../core/theme/streak_colors.dart';
import '../../shared/widgets/streak_box.dart';

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

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What the boxes mean',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                for (final cell in HeatmapCell.values)
                  if (cell != HeatmapCell.none)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          StreakBox(cell: cell, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            StreakColors.labelFor(cell),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 8),
                const Text(
                  'Skipped days stay grey.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

        final streakLabel = liveStreak == 1
            ? '1 day streak'
            : '$liveStreak day streak';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Streak Map',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showInfoSheet(context),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
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
                final isToday = key == _formatDateKey(today);
                
                final labelStr = '$key - ${StreakColors.labelFor(cellState)}';

                return Tooltip(
                  message: labelStr,
                  child: Semantics(
                    label: labelStr,
                    child: StreakBox(
                      cell: cellState,
                      size: boxSize,
                      isToday: isToday,
                      animate: false,
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
}
