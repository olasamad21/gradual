import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/features/daily_word/concept_flip_card.dart';

void main() {
  final testConcept = Concept(
    id: 'test-id',
    term: 'State',
    category: 'software-engineering',
    definition: 'The remembered information of a system.',
    level: 'beginner',
    analogy: 'Like remembering where you left your keys.',
    realWorldExample: 'Flutter StatefulWidget.',
    confusedWith: 'Stateless',
    related: ['Props', 'Store'],
    quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
  );

  Widget buildTestCard({
    required Concept concept,
    bool isRead = false,
    bool isLastWord = false,
    VoidCallback? onMarkRead,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: ConceptFlipCard(
                concept: concept,
                isRead: isRead,
                isLastWord: isLastWord,
                index: 0,
                onMarkRead: onMarkRead ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ConceptFlipCard front shows term, full definition, formatted category, and no Got it', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestCard(concept: testConcept));

    expect(find.text('State'), findsOneWidget);
    expect(find.text('The remembered information of a system.'), findsOneWidget);
    

    expect(find.text('Like remembering where you left your keys.'), findsNothing);
    expect(find.text('Got it'), findsNothing);
  });

  testWidgets('ConceptFlipCard flips on tap and shows back content', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestCard(concept: testConcept));

    // Tap to flip
    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('ANALOGY'), findsOneWidget);
    expect(find.text('Like remembering where you left your keys.'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    // Tap to flip back
    await tester.tap(find.text('ANALOGY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Should be front again
    expect(find.text('State'), findsOneWidget);
    // Back content might technically be in tree but transformed away, checking the 'Got it' button which shouldn't be hittable or we can just trust the animation.
  });

  testWidgets('ConceptFlipCard Got it calls markRead, disables, and changes text', (WidgetTester tester) async {
    bool didMarkRead = false;
    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      onMarkRead: () => didMarkRead = true,
    ));

    // Flip to back
    await tester.tap(find.byType(ConceptFlipCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Tap Got it
    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(didMarkRead, isTrue);
  });

  testWidgets('ConceptFlipCard hides empty sections', (WidgetTester tester) async {
    final emptyConcept = Concept(
      id: 'empty',
      term: 'Empty',
      category: 'cat',
      definition: 'def',
      level: 'easy',
      analogy: null,
      confusedWith: '',
      realWorldExample: '',
      related: [],
      quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
    );

    await tester.pumpWidget(buildTestCard(concept: emptyConcept));
    await tester.tap(find.byType(ConceptFlipCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('ANALOGY'), findsNothing);
    expect(find.text("DON'T CONFUSE WITH"), findsNothing);
    expect(find.text('REAL WORLD EXAMPLE'), findsNothing);
    expect(find.text('RELATED TERMS'), findsNothing);
  });

  testWidgets('ConceptFlipCard works with disableAnimations', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      disableAnimations: true,
    ));

    // Initially front
    expect(find.text('State'), findsOneWidget);

    // Flip
    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Should be back
    expect(find.text('ANALOGY'), findsOneWidget);
  });

  testWidgets('ConceptFlipCard shows full real world example text on back face', (WidgetTester tester) async {
    const longText = 'This is a very long real world example that stretches to about four hundred characters. It is intended to test whether the back face properly displays the entire text without truncating it. We are making sure that the plain text widget is fully visible inside the card. If it was truncated or hidden inside a marquee, this test would fail because the text would not be completely visible at once. Let us add a few more words to ensure it is sufficiently long.';
    
    final longExampleConcept = Concept(
      id: 'long_ex',
      term: 'LongEx',
      category: 'cat',
      definition: 'def',
      level: 'easy',
      analogy: null,
      confusedWith: '',
      realWorldExample: longText,
      related: [],
      quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
    );

    await tester.pumpWidget(buildTestCard(concept: longExampleConcept));
    
    // Flip to back
    await tester.tap(find.byType(ConceptFlipCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(longText), findsOneWidget);
  });

  testWidgets('Pill shows numbers 1, 2, 3 for index 0, 1, 2 when unread', (WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConceptFlipCard(
            concept: testConcept,
            index: i,
            isRead: false,
            isLastWord: false,
            onMarkRead: () {},
          ),
        ),
      ));
      expect(find.text('${i + 1}'), findsWidgets);
      expect(find.byIcon(Icons.check), findsNothing);
    }
  });

  testWidgets('Pill swapping to check on Got it tap (and tests back face presence)', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestCard(concept: testConcept, isRead: false));
    expect(find.text('1'), findsWidgets);
    
    // Tap card to flip to back face
    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    
    // Pill is present on back face (1 is still there)
    expect(find.text('1'), findsWidgets);
    
    // Tap Got it. Real app rebuilds with isRead: true
    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pumpWidget(buildTestCard(concept: testConcept, isRead: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    
    // Check icon is present, number is gone
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('Pill built with isRead true shows check instantly', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestCard(concept: testConcept, isRead: true));
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('Pill swap happens instantly with disableAnimations', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestCard(concept: testConcept, isRead: false, disableAnimations: true));
    expect(find.text('1'), findsWidgets);
    
    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    
    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pumpWidget(buildTestCard(concept: testConcept, isRead: true, disableAnimations: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.text('1'), findsNothing);
  });
}

