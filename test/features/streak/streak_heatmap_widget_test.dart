import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/streak/streak_heatmap_widget.dart';

void main() {
  testWidgets('StreakHeatmapWidget basic rendering', (WidgetTester tester) async {
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

    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('No active streak'), findsOneWidget);

    expect(find.text('None'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Perfect'), findsOneWidget);
    expect(find.text('Fair'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });
}
