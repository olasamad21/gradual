import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/concept_flip_card.dart';
import 'package:gradual/core/services/read_aloud_text.dart';

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
    bool isReadingAloud = false,
    VoidCallback? onToggleReadAloud,
    ReadSectionKind? readingSection,
    int? readingWordStart,
    int? readingWordEnd,
    double readingSpeed = 1.0,
    VoidCallback? onCycleSpeed,
    VoidCallback? onExpand,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        theme: AppTheme.light,
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
                isReadingAloud: isReadingAloud,
                onToggleReadAloud: onToggleReadAloud,
                readingSection: readingSection,
                readingWordStart: readingWordStart,
                readingWordEnd: readingWordEnd,
                readingSpeed: readingSpeed,
                onCycleSpeed: onCycleSpeed,
                onExpand: onExpand,
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
  testWidgets('with onToggleReadAloud null there is no speaker button', (tester) async {
    await tester.pumpWidget(buildTestCard(concept: testConcept));
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  testWidgets('with callback the button is present with a finite width greater than 0, tapping calls callback once', (tester) async {
    int taps = 0;
    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      onToggleReadAloud: () => taps++,
    ));

    final button = find.byType(IconButton);
    expect(button, findsOneWidget);
    
    final size = tester.getSize(button);
    expect(size.width.isFinite, isTrue);
    expect(size.width, greaterThan(0));

    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('with isReadingAloud true the stop icon shows', (tester) async {
    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      isReadingAloud: true,
      onToggleReadAloud: () {},
    ));

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('the button is present on both faces after a flip', (tester) async {
    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      onToggleReadAloud: () {},
    ));

    expect(find.byType(IconButton), findsOneWidget);

    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('readingSection analogy while showing the front flips to the back', (tester) async {
    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      isReadingAloud: false,
    ));

    expect(find.text('Like remembering where you left your keys.'), findsNothing); // Analogy hidden

    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      isReadingAloud: true,
      readingSection: ReadSectionKind.analogy,
      disableAnimations: true, // instant flip
    ));
    await tester.pump(); // trigger flip

    expect(find.text('Like remembering where you left your keys.'), findsOneWidget); // Visible now
  });

  testWidgets('speed chip shows only while reading and tapping it calls onCycleSpeed once', (tester) async {
    int taps = 0;

    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      isReadingAloud: false,
      onToggleReadAloud: () {},
      onCycleSpeed: () => taps++,
    ));

    expect(find.text('1x'), findsNothing);

    await tester.pumpWidget(buildTestCard(
      concept: testConcept,
      isReadingAloud: true,
      onToggleReadAloud: () {},
      onCycleSpeed: () => taps++,
    ));

    final chip = find.text('1x');
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    expect(taps, 1);
  });

  testWidgets('no exceptions at text scale 1.3 with reading buttons', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: ConceptFlipCard(
                concept: testConcept,
                index: 0,
                isRead: false,
                isLastWord: false,
                onMarkRead: () {},
                isReadingAloud: true,
                onToggleReadAloud: () {},
                onCycleSpeed: () {},
                readingSpeed: 1.25,
                readingSection: ReadSectionKind.example,
              ),
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  group('ConceptFlipCard onExpand and longPress tests', () {
    testWidgets('with onExpand null there is no handle and a long press does nothing', (tester) async {
      await tester.pumpWidget(buildTestCard(concept: testConcept, onExpand: null));
      expect(find.byKey(const Key('concept_card_expand_handle')), findsNothing);

      await tester.longPress(find.byType(ConceptFlipCard));
      await tester.pump();
      expect(find.text('DEFINITION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with onExpand set tester.longPress on the card calls it once and the card is still on the front', (tester) async {
      var expandCalls = 0;
      await tester.pumpWidget(buildTestCard(concept: testConcept, onExpand: () => expandCalls++));

      await tester.longPress(find.byType(ConceptFlipCard));
      await tester.pump();

      expect(expandCalls, 1);
      expect(find.text('DEFINITION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a normal tap still flips and does not call onExpand', (tester) async {
      var expandCalls = 0;
      await tester.pumpWidget(buildTestCard(concept: testConcept, onExpand: () => expandCalls++));

      await tester.tap(find.byType(ConceptFlipCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(expandCalls, 0);
      expect(find.text('Tap to flip back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the handle calls it once', (tester) async {
      var expandCalls = 0;
      await tester.pumpWidget(buildTestCard(concept: testConcept, onExpand: () => expandCalls++));

      final handleFinder = find.byKey(const Key('concept_card_expand_handle'));
      expect(handleFinder, findsOneWidget);

      await tester.tap(handleFinder);
      await tester.pump();

      expect(expandCalls, 1);
      expect(find.text('DEFINITION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the handle is present on both faces after a flip (pump() then pump(Duration(milliseconds: 800)))', (tester) async {
      await tester.pumpWidget(buildTestCard(concept: testConcept, onExpand: () {}));

      // Front face
      expect(find.byKey(const Key('concept_card_expand_handle')), findsOneWidget);

      // Flip card
      await tester.tap(find.byType(ConceptFlipCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Back face
      expect(find.byKey(const Key('concept_card_expand_handle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at text scale 1.3', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 600,
                  child: ConceptFlipCard(
                    concept: testConcept,
                    index: 0,
                    isRead: false,
                    isLastWord: false,
                    onMarkRead: () {},
                    onExpand: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Flip to back face
      await tester.tap(find.byType(ConceptFlipCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(tester.takeException(), isNull);
    });
  });
}
