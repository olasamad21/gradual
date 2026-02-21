import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';

class StreakHeatmapWidget extends StatelessWidget {
  const StreakHeatmapWidget({
    super.key,
    required this.activityLog,
    this.daysToShow = 365, // Kept for your app's compatibility
  });

  final ActivityLog activityLog;
  final int daysToShow;

  // I kept your awesome color logic intact for when we use real data!
  Color _colorForEntry(ActivityLogEntry? entry) {
    if (entry == null) {
      return const Color(0xFFEAECEF); // Empty gray
    }
    switch (entry.difficulty) {
      case 'junior':
        return const Color(0xFFC8E6C9); // light green
      case 'senior':
        return const Color(0xFF81C784); // medium green
      case 'lead':
      case 'tech_lead':
        return const Color(0xFF388E3C); // dark green
      default:
        return const Color(0xFFC8E6C9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate exactly how many boxes fit on the user's screen
        const double boxSize = 14.0;
        const double spacing = 4.0;
        final double maxWidth = constraints.maxWidth == double.infinity ? 300 : constraints.maxWidth;
        final int columnCount = (maxWidth / (boxSize + spacing)).floor();
        final int totalDaysToShow = columnCount * 2; // Exactly 2 Rows

        final today = DateTime.now().toUtc();
        final dates = List.generate(
          totalDaysToShow,
              (i) => today.subtract(Duration(days: totalDaysToShow - 1 - i)),
        );

        // --- 🧪 PLACEHOLDER DATA FOR UI TESTING ---
        // Simulating a 5-day streak and random past activity with different shades of green
        final Map<String, Color> dummyColors = {};
        for (int i = 0; i < totalDaysToShow; i++) {
          final d = dates[i];
          final dateStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

          if (i > totalDaysToShow - 6) {
            dummyColors[dateStr] = const Color(0xFF388E3C); // Fake 5-day streak at tech_lead difficulty!
          } else if (i % 7 == 0) {
            dummyColors[dateStr] = const Color(0xFF81C784); // occasional senior difficulty
          } else if (i % 3 == 0) {
            dummyColors[dateStr] = const Color(0xFFC8E6C9); // frequent junior difficulty
          }
        }
        // ------------------------------------------

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Activity",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Row(
                  children: const [
                    Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      "5 Day Streak!",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10),

            // No more SizedBox height restriction!
            GridView.builder(
              shrinkWrap: true, // Tells the grid to take exactly the space it needs
              padding: EdgeInsets.zero, // Removes invisible default padding
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
                final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                // For the UI test, we use the dummyColors map.
                // Later, we will switch this back to: final entry = activityLog[key];
                final Color boxColor = dummyColors[key] ?? const Color(0xFFEAECEF);

                return Container(
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.05),
                      width: 1,
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