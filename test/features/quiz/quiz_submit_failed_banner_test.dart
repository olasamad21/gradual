import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/quiz/quiz_submit_failed_banner.dart';
import 'package:gradual/core/theme/app_theme.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Column(
          children: [child],
        ),
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

  testWidgets('pumps the widget and asserts tester.takeException() is null (isSaving false)', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        QuizSubmitFailedBanner(
          isSaving: false,
          onRetry: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rendered width is finite and greater than 0 (isSaving false)', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        QuizSubmitFailedBanner(
          isSaving: false,
          onRetry: () {},
        ),
      ),
    );
    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.width.isFinite, isTrue);
    expect(size.width > 0, isTrue);
  });

  testWidgets('pumps the widget and asserts tester.takeException() is null (isSaving true)', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        QuizSubmitFailedBanner(
          isSaving: true,
          onRetry: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rendered width is finite and greater than 0 (isSaving true)', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        QuizSubmitFailedBanner(
          isSaving: true,
          onRetry: () {},
        ),
      ),
    );
    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.width.isFinite, isTrue);
    expect(size.width > 0, isTrue);
  });
}
