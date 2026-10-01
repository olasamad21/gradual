import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/streak/streak_heatmap_widget.dart';

void main() {
  testWidgets('StreakHeatmapWidget renders compact view with NO legend strings', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakHeatmapWidget(
            rawActivityLog: const {},
            liveStreak: 0,
            today: DateTime(2026, 10, 10),
          ),
        ),
      ),
    );

    expect(find.text('Streak Map'), findsOneWidget);
    expect(find.text('0 day streak'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);

    // Verify legend strings DO NOT appear on the screen
    final bannedStrings = ['None', 'Partial', 'Perfect', 'Fair', 'Good', 'Excellent', 'Failed', 'Missed'];
    for (final s in bannedStrings) {
      expect(find.text(s), findsNothing, reason: 'String "$s" should not appear initially');
    }

    // Tap info icon
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle(); // Wait for bottom sheet animation

    // Expect sheet title
    expect(find.text('What the boxes mean'), findsOneWidget);
  });
}
