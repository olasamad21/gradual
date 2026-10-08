import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/quiz/unsaved_quiz_card.dart';
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

  testWidgets('pumps the widget and asserts tester.takeException() is null (isSaving false)', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        UnsavedQuizCard(
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
        UnsavedQuizCard(
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
        UnsavedQuizCard(
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
        UnsavedQuizCard(
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
