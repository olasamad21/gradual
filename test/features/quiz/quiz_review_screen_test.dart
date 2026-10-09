import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/quiz/quiz_models.dart';
import 'package:gradual/features/quiz/quiz_review_screen.dart';

void main() {
  Widget buildTestableWidget(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: child,
      ),
    );
  }

  final q1 = QuizQuestion(
    id: 'q1',
    text: 'Q1 text',
    options: ['A', 'B'],
    correctIndex: 0,
    explanation: '',
    sourceWord: '',
    type: 'mcq',
  );
  final q2 = QuizQuestion(
    id: 'q2',
    text: 'Q2 text',
    options: ['A', 'B'],
    correctIndex: 0,
    explanation: '',
    sourceWord: '',
    type: 'mcq',
  );
  final q3 = QuizQuestion(
    id: 'q3',
    text: 'Q3 text',
    options: ['A', 'B'],
    correctIndex: 0,
    explanation: '',
    sourceWord: '',
    type: 'mcq',
  );

  final answers3 = [
    QuizAnswer(question: q1, selectedIndex: 1), // wrong
    QuizAnswer(question: q2, selectedIndex: 0), // correct
    QuizAnswer(question: q3, selectedIndex: 0), // correct
  ];

  testWidgets('with 3 answers (1 wrong, 2 correct): boxes 1, 2 and 3 are found by key with finite width and height greater than 0; the first question text is visible; the second question text is not found', (tester) async {
    await tester.pumpWidget(buildTestableWidget(QuizReviewScreen(answers: answers3)));

    for (int i = 0; i < 3; i++) {
      final boxFinder = find.byKey(ValueKey('review_box_$i'));
      expect(boxFinder, findsOneWidget);
      final size = tester.getSize(boxFinder);
      expect(size.width.isFinite, isTrue);
      expect(size.height.isFinite, isTrue);
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    }

    expect(find.text('Q1 text'), findsOneWidget);
    expect(find.text('Q2 text'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping box 3 (then pump() and pump(Duration(milliseconds: 400))) shows the third question text and the "Question 3 of 3" label', (tester) async {
    await tester.pumpWidget(buildTestableWidget(QuizReviewScreen(answers: answers3)));

    await tester.tap(find.byKey(const ValueKey('review_box_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Q3 text'), findsOneWidget);
    expect(find.text('Question 3 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the PageView left by 400 pixels shows the second question and the Semantics of box 2 reports selected', (tester) async {
    await tester.pumpWidget(buildTestableWidget(QuizReviewScreen(answers: answers3)));

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Q2 text'), findsOneWidget);

    final semanticsWidget = tester.widget<Semantics>(
      find.ancestor(
        of: find.byKey(const ValueKey('review_box_1')),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(semanticsWidget.properties.selected, isTrue);

    expect(tester.takeException(), isNull);
  });

  testWidgets("the Semantics label of the wrong answer's box contains 'incorrect' and the labels of the correct answers' boxes do not", (tester) async {
    await tester.pumpWidget(buildTestableWidget(QuizReviewScreen(answers: answers3)));

    final s0 = tester.getSemantics(find.byKey(const ValueKey('review_box_0')));
    expect(s0.label.contains('incorrect'), isTrue);

    final s1 = tester.getSemantics(find.byKey(const ValueKey('review_box_1')));
    expect(s1.label.contains('incorrect'), isFalse);

    final s2 = tester.getSemantics(find.byKey(const ValueKey('review_box_2')));
    expect(s2.label.contains('incorrect'), isFalse);

    expect(tester.takeException(), isNull);
  });

  testWidgets('initialIndex: 1 starts on the second question', (tester) async {
    await tester.pumpWidget(buildTestableWidget(QuizReviewScreen(answers: answers3, initialIndex: 1)));

    expect(find.text('Q2 text'), findsOneWidget);
    expect(find.text('Q1 text'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('with disableAnimations true (MediaQuery wrapped around the app) tapping a box still moves to that question', (tester) async {
    await tester.pumpWidget(buildTestableWidget(QuizReviewScreen(answers: answers3), disableAnimations: true));

    await tester.tap(find.byKey(const ValueKey('review_box_2')));
    await tester.pump();

    expect(find.text('Q3 text'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with 10 answers and MediaQuery textScaler of TextScaler.linear(1.3): tester.takeException() is null and all 10 boxes are found', (tester) async {
    final answers10 = List.generate(10, (i) => QuizAnswer(
      question: QuizQuestion(
        id: 'q$i',
        text: 'Q$i text',
        options: ['A', 'B'],
        correctIndex: 0,
        explanation: '',
        sourceWord: '',
        type: 'mcq',
      ),
      selectedIndex: 0,
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.3),
          ),
          child: QuizReviewScreen(answers: answers10),
        ),
      ),
    );

    for (int i = 0; i < 10; i++) {
      expect(find.byKey(ValueKey('review_box_$i')), findsOneWidget);
    }
    
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty list shows "No answers to review."', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const QuizReviewScreen(answers: [])));

    expect(find.text('No answers to review.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
