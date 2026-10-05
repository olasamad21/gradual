import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/quiz/unsaved_quiz_card.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('UnsavedQuizCard shows text and button; tap calls onRetry once', (tester) async {
    int retryCount = 0;

    await tester.pumpWidget(
      buildTestableWidget(
        UnsavedQuizCard(
          isSaving: false,
          onRetry: () => retryCount++,
        ),
      ),
    );

    expect(find.text('You have an unsaved quiz result'), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);

    await tester.tap(find.text('Retry save'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('UnsavedQuizCard when isSaving is true shows the indicator and the tap does nothing', (tester) async {
    int retryCount = 0;

    await tester.pumpWidget(
      buildTestableWidget(
        UnsavedQuizCard(
          isSaving: true,
          onRetry: () => retryCount++,
        ),
      ),
    );

    expect(find.text('Retry save'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 100)); // Just a small advance

    expect(retryCount, 0);
  });
}
