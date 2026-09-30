import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/features/daily_word/concept_card.dart';

void main() {
  final testConcept = Concept(
    id: 'test-concept',
    term: 'Test Concept',
    category: 'Testing',
    level: 'beginner',
    definition: 'This is a test definition.',
    analogy: 'Like testing a car.',
    realWorldExample: 'A real test.',
    confusedWith: 'Production',
    related: ['QA'],
    quiz: ConceptQuiz(
      question: '?',
      options: ['1', '2', '3', '4'],
      answerIndex: 0,
      explanation: 'Because',
    ),
  );

  final testConceptNoAnalogy = Concept(
    id: 'test-concept-2',
    term: 'Test Concept 2',
    category: 'Testing',
    level: 'beginner',
    definition: 'This is a test definition.',
    realWorldExample: 'A real test.',
    related: [],
    quiz: ConceptQuiz(
      question: '?',
      options: ['1', '2', '3', '4'],
      answerIndex: 0,
      explanation: 'Because',
    ),
  );

  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('ConceptCard starts collapsed and expands on tap', (tester) async {
    bool markedRead = false;

    await tester.pumpWidget(wrapInApp(
      ConceptCard(
        concept: testConcept,
        isRead: false,
        onMarkRead: () => markedRead = true,
      ),
    ));

    expect(find.text('Test Concept'), findsOneWidget);
    expect(find.text('This is a test definition.'), findsNothing);

    await tester.tap(find.text('Test Concept'));
    await tester.pumpAndSettle();

    expect(find.text('This is a test definition.'), findsOneWidget);
    expect(find.text('Like testing a car.'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(markedRead, isTrue);
  });

  testWidgets('ConceptCard disables Got it button and forces collapse when read', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ConceptCard(
        concept: testConcept,
        isRead: false,
        onMarkRead: () {},
      ),
    ));

    await tester.tap(find.text('Test Concept'));
    await tester.pumpAndSettle();

    expect(find.text('Got it'), findsOneWidget);

    await tester.pumpWidget(wrapInApp(
      ConceptCard(
        concept: testConcept,
        isRead: true,
        onMarkRead: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('This is a test definition.'), findsNothing);
    
    await tester.tap(find.text('Test Concept'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('ConceptCard hides optional fields when null', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ConceptCard(
        concept: testConceptNoAnalogy,
        isRead: false,
        onMarkRead: () {},
      ),
    ));

    await tester.tap(find.text('Test Concept 2'));
    await tester.pumpAndSettle();

    expect(find.text('This is a test definition.'), findsOneWidget);
    expect(find.text('ANALOGY'), findsNothing);
    expect(find.text('DON\'T CONFUSE WITH'), findsNothing);
    expect(find.text('RELATED TERMS'), findsNothing);
  });
}
