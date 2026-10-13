import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/concept_reader.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';

class FakeTodayConceptsController extends TodayConceptsController {
  FakeTodayConceptsController(this._fakeState);
  final TodayConceptsState _fakeState;

  @override
  Future<TodayConceptsState> build() async => _fakeState;
}

void main() {
  final fullConcept = Concept(
    id: 'c1',
    term: 'Encapsulation',
    category: 'software_engineering',
    definition: 'Bundling data and methods that operate on that data.',
    level: 'beginner',
    analogy: 'A medicine capsule containing specific ingredients.',
    realWorldExample: 'A bank account hiding the raw balance.',
    confusedWith: 'Abstraction',
    related: ['OOP', 'Polymorphism'],
    quiz: const ConceptQuiz(
      question: 'What is encapsulation?',
      options: ['Bundling data', 'Looping', 'Inheritance'],
      answerIndex: 0,
      explanation: 'Bundling data and methods.',
    ),
  );

  final minimalConcept = Concept(
    id: 'c2',
    term: 'Polymorphism',
    category: 'software_engineering',
    definition: 'Provision of a single interface to entities of different types.',
    level: 'beginner',
    analogy: '',
    realWorldExample: 'Drawing shapes with a single draw call.',
    confusedWith: null,
    related: const [],
    quiz: const ConceptQuiz(
      question: 'Question',
      options: ['A', 'B'],
      answerIndex: 0,
      explanation: 'Explanation',
    ),
  );

  Widget createTestHarness({
    required Concept concept,
    required VoidCallback onMarkRead,
    Set<String> readConceptIds = const {},
    bool disableAnimations = false,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final fakeState = TodayConceptsState(
      concepts: [concept],
      readConceptIds: readConceptIds,
      isFallback: false,
      userUid: 'uid123',
      liveStreak: 1,
    );

    return ProviderScope(
      overrides: [
        todayConceptsControllerProvider.overrideWith(
          () => FakeTodayConceptsController(fakeState),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          textScaler: textScaler,
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  openConceptReader(
                    ctx,
                    concept: concept,
                    index: 0,
                    total: 1,
                    onMarkRead: onMarkRead,
                  );
                },
                child: const Text('Open Reader'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ConceptReader tests', () {
    testWidgets('all sections show in order, empty analogy and confused-with are skipped', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check all section headers in fullConcept
      final defFinder = find.text('DEFINITION');
      final analogyFinder = find.text('ANALOGY');
      final exampleFinder = find.text('REAL WORLD EXAMPLE');
      final confusedFinder = find.text("DON'T CONFUSE WITH");
      final relatedFinder = find.text('RELATED TERMS');

      expect(defFinder, findsOneWidget);
      expect(analogyFinder, findsOneWidget);
      expect(exampleFinder, findsOneWidget);
      expect(confusedFinder, findsOneWidget);
      expect(relatedFinder, findsOneWidget);

      // Verify order by vertical position
      final defTop = tester.getTopLeft(defFinder).dy;
      final analogyTop = tester.getTopLeft(analogyFinder).dy;
      final exampleTop = tester.getTopLeft(exampleFinder).dy;
      final confusedTop = tester.getTopLeft(confusedFinder).dy;
      final relatedTop = tester.getTopLeft(relatedFinder).dy;

      expect(defTop, lessThan(analogyTop));
      expect(analogyTop, lessThan(exampleTop));
      expect(exampleTop, lessThan(confusedTop));
      expect(confusedTop, lessThan(relatedTop));

      // Close reader
      await tester.tap(find.byKey(const Key('reader_close_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now test minimalConcept where analogy and confused-with are empty/null
      await tester.pumpWidget(
        createTestHarness(
          concept: minimalConcept,
          onMarkRead: () {},
        ),
      );
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('DEFINITION'), findsOneWidget);
      expect(find.text('REAL WORLD EXAMPLE'), findsOneWidget);
      expect(find.text('ANALOGY'), findsNothing);
      expect(find.text("DON'T CONFUSE WITH"), findsNothing);
      expect(find.text('RELATED TERMS'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Got it is enabled when the concept is unread and calls onMarkRead once', (tester) async {
      var markReadCalls = 0;
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () => markReadCalls++,
          readConceptIds: {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final buttonFinder = find.descendant(
        of: find.byType(ConceptReader),
        matching: find.widgetWithText(ElevatedButton, 'Got it'),
      );
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNotNull);

      await tester.tap(buttonFinder);
      await tester.pump();
      expect(markReadCalls, 1);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('when the concept is read the button shows the check and is disabled', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
          readConceptIds: {'c1'},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final buttonFinder = find.descendant(
        of: find.byType(ConceptReader),
        matching: find.widgetWithText(ElevatedButton, 'Got it \u2713'),
      );
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button pops the route', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ConceptReader), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_close_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ConceptReader), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging the top zone down 200 pixels and releasing pops the route', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ConceptReader), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('reader_top_drag_zone')),
        const Offset(0, 200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging 40 pixels and releasing keeps it open with content back at original position', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ConceptReader), findsOneWidget);

      final initialTop = tester.getTopLeft(find.text('Encapsulation')).dy;

      await tester.drag(
        find.byKey(const Key('reader_top_drag_zone')),
        const Offset(0, 40),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsOneWidget);
      final finalTop = tester.getTopLeft(find.text('Encapsulation')).dy;
      expect(finalTop, closeTo(initialTop, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('upward drag does nothing', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ConceptReader), findsOneWidget);

      final initialTop = tester.getTopLeft(find.text('Encapsulation')).dy;

      await tester.drag(
        find.byKey(const Key('reader_top_drag_zone')),
        const Offset(0, -60),
      );
      await tester.pump();

      expect(find.byType(ConceptReader), findsOneWidget);
      final currentTop = tester.getTopLeft(find.text('Encapsulation')).dy;
      expect(currentTop, closeTo(initialTop, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the button and the close button have finite width greater than 0', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final buttonBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(ConceptReader),
          matching: find.widgetWithText(ElevatedButton, 'Got it'),
        ),
      );
      expect(buttonBox.size.width.isFinite, isTrue);
      expect(buttonBox.size.width, greaterThan(0));

      final closeBox = tester.renderObject<RenderBox>(
        find.byKey(const Key('reader_close_button')),
      );
      expect(closeBox.size.width.isFinite, isTrue);
      expect(closeBox.size.width, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 throws nothing', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
          textScaler: const TextScaler.linear(1.3),
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });

    testWidgets('with disableAnimations true it opens and closes without exceptions', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          concept: fullConcept,
          onMarkRead: () {},
          disableAnimations: true,
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ConceptReader), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_close_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ConceptReader), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
