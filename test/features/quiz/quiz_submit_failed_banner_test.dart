import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/quiz/quiz_submit_failed_banner.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('shows message and Retry button; calls onRetry on tap', (tester) async {
    int retryCount = 0;

    await tester.pumpWidget(
      buildTestableWidget(
        QuizSubmitFailedBanner(
          isSaving: false,
          onRetry: () => retryCount++,
        ),
      ),
    );

    expect(find.text("Couldn't save your score. Check your connection and retry."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    
    // Check Semantics label starts with the expected text
    final semantics = tester.getSemantics(find.byType(QuizSubmitFailedBanner));
    expect(semantics.label, startsWith('Quiz score not saved'));

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('when isSaving is true, shows indicator, no text, does not call onRetry', (tester) async {
    int retryCount = 0;

    await tester.pumpWidget(
      buildTestableWidget(
        QuizSubmitFailedBanner(
          isSaving: true,
          onRetry: () => retryCount++,
        ),
      ),
    );

    expect(find.text('Retry'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 100)); // Just a small advance, no pumpAndSettle

    expect(retryCount, 0);
  });
}
