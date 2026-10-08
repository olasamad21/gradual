import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/quiz/quiz_models.dart';
import 'package:gradual/features/quiz/quiz_screen.dart';
import 'package:gradual/features/quiz/quiz_review_screen.dart';
import 'package:gradual/shared/widgets/app_shell.dart';

void main() {
  final testQuestion = QuizQuestion(
    id: 'q1',
    text: 'What is the answer?',
    options: ['A', 'B', 'C', 'D'],
    correctIndex: 0,
    explanation: 'Because A is correct.',
    sourceWord: 'word',
    type: 'mcq',
  );

  final testAnswers = [
    QuizAnswer(question: testQuestion, selectedIndex: 0),
  ];

  final completedWithAnswers = CompletedQuizResult(
    sessionDateId: 'test_date',
    score: 1,
    total: 1,
    tier: 'Gold',
    answers: testAnswers,
  );

  final completedWithoutAnswers = CompletedQuizResult(
    sessionDateId: 'test_date',
    score: 1,
    total: 1,
    tier: 'Gold',
    answers: null,
  );

  Widget buildTestableWidget(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }

  testWidgets('result screen with answers shows score, Review and Done, no inline questions', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestableWidget(QuizResultScreen(result: completedWithAnswers), container));

    expect(find.text('You scored 100%'), findsOneWidget);
    expect(find.text('Review answers'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('What is the answer?'), findsNothing); // No inline question
    expect(tester.takeException(), isNull);

    final reviewSize = tester.getSize(find.widgetWithText(OutlinedButton, 'Review answers'));
    expect(reviewSize.width.isFinite, isTrue);
    expect(reviewSize.width, greaterThan(0));

    final doneSize = tester.getSize(find.widgetWithText(FilledButton, 'Done'));
    expect(doneSize.width.isFinite, isTrue);
    expect(doneSize.width, greaterThan(0));
  });

  testWidgets('result screen with answers null shows unavailable text and Done, no Review', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestableWidget(QuizResultScreen(result: completedWithoutAnswers), container));

    expect(find.text('You scored 100%'), findsOneWidget);
    expect(find.text("Answer details aren't available on this device."), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Review answers'), findsNothing);
    expect(tester.takeException(), isNull);

    final doneSize = tester.getSize(find.widgetWithText(FilledButton, 'Done'));
    expect(doneSize.width.isFinite, isTrue);
    expect(doneSize.width, greaterThan(0));
  });

  testWidgets('tapping Review answers opens review screen with question text', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestableWidget(QuizResultScreen(result: completedWithAnswers), container));
    await tester.tap(find.text('Review answers'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizReviewScreen), findsOneWidget);
    expect(find.text('What is the answer?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Done closes screen and sets tab to 0', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appShellTabProvider.notifier).state = 1;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => QuizResultScreen(result: completedWithAnswers),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(container.read(appShellTabProvider), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back sets tab to 0', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appShellTabProvider.notifier).state = 1;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => QuizResultScreen(result: completedWithAnswers),
            );
          },
        ),
      ),
    ));

    Navigator.maybePop(tester.element(find.byType(QuizResultScreen)));
    await tester.pumpAndSettle();

    expect(container.read(appShellTabProvider), 0);
    expect(tester.takeException(), isNull);
  });
}
