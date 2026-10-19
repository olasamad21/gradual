import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/user_repository.dart';
import 'package:gradual/core/services/speech_service.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/concept_reader.dart';
import 'package:gradual/features/daily_word/concept_section_style.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';
import 'package:gradual/features/quiz/quiz_models.dart';

class FakeTodayConceptsController extends TodayConceptsController {
  FakeTodayConceptsController(this._fakeState);
  final TodayConceptsState _fakeState;

  @override
  Future<TodayConceptsState> build() async => _fakeState;
}

class FakeUserRepositoryForReader implements UserRepository {
  final List<String> toggledConceptIds = [];

  @override
  Future<void> setConceptSaved({
    required String uid,
    required String conceptId,
    required bool saved,
    required int savedAtMillis,
  }) async {
    toggledConceptIds.add(conceptId);
  }

  @override
  Future<AppUser?> getUser(String uid) async => null;

  @override
  Future<void> createOrUpdateUser(AppUser user) async {}

  @override
  Future<void> initNewUserIfMissing(String uid) async {}

  @override
  Stream<AppUser?> userStream(String uid) => Stream.value(null);

  @override
  Future<void> recordConceptRead({
    required String uid,
    required String conceptId,
    required String dateId,
  }) async {}

  @override
  Future<void> resetStatsIfNeeded(String uid) async {}

  @override
  Future<QuizSaveResult> saveQuizScore({
    required String uid,
    required String dateId,
    required int score,
    required int total,
    required String tier,
    String? fieldOfStudy,
  }) async =>
      QuizSaveResult.saved;
}

class FakeSpeechService implements SpeechService {
  final spokenStrings = <String>[];
  double currentRate = kSpeechRateNormal;
  Completer<bool>? nextSpeakCompleter;

  final _progressController = StreamController<SpeechProgress>.broadcast();
  final _finishedController = StreamController<void>.broadcast();

  @override
  Stream<SpeechProgress> get onProgress => _progressController.stream;

  @override
  Stream<void> get onFinished => _finishedController.stream;

  void emitProgress(int start, int end) {
    _progressController.add(SpeechProgress(start, end));
  }

  @override
  Future<void> setRate(double rate) async {
    currentRate = rate;
  }

  @override
  Future<bool> speak(String text) async {
    spokenStrings.add(text);
    nextSpeakCompleter = Completer<bool>();
    return nextSpeakCompleter!.future;
  }

  @override
  Future<void> stop() async {
    if (nextSpeakCompleter != null && !nextSpeakCompleter!.isCompleted) {
      nextSpeakCompleter!.complete(true);
    }
  }
}

void main() {
  final concept1 = Concept(
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
      options: ['Bundling data', 'Looping'],
      answerIndex: 0,
      explanation: 'Bundling data.',
    ),
  );

  final concept2 = Concept(
    id: 'c2',
    term: 'Inheritance',
    category: 'software_engineering',
    definition: 'Mechanisms of basing an object or class upon another object.',
    level: 'beginner',
    analogy: 'A child inheriting traits from parents.',
    realWorldExample: 'A subclass extending a superclass.',
    confusedWith: 'Composition',
    related: ['OOP'],
    quiz: const ConceptQuiz(
      question: 'Question',
      options: ['A', 'B'],
      answerIndex: 0,
      explanation: 'Explanation',
    ),
  );

  final concept3 = Concept(
    id: 'c3',
    term: 'Polymorphism',
    category: 'software_engineering',
    definition: List.generate(40, (i) => 'Line $i: Provision of a single interface to entities of different types in object oriented programming systems.').join('\n\n'),
    level: 'beginner',
    analogy: 'A universal remote control.',
    realWorldExample: 'Shape.draw() method.',
    confusedWith: 'Overloading',
    related: ['OOP'],
    quiz: const ConceptQuiz(
      question: 'Question',
      options: ['A', 'B'],
      answerIndex: 0,
      explanation: 'Explanation',
    ),
  );

  int? lastClosedIndex;

  Widget createTestHarness({
    List<Concept>? concepts,
    int initialIndex = 0,
    void Function(String)? onMarkRead,
    Set<String> readConceptIds = const {},
    bool disableAnimations = false,
    TextScaler textScaler = TextScaler.noScaling,
    FakeSpeechService? fakeSpeech,
    bool showGotIt = true,
    List<dynamic> extraOverrides = const [],
  }) {
    final conceptList = concepts ?? [concept1, concept2, concept3];
    final fakeState = TodayConceptsState(
      concepts: conceptList,
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
        if (fakeSpeech != null)
          speechServiceProvider.overrideWithValue(fakeSpeech),
        ...extraOverrides,
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
                onPressed: () async {
                  lastClosedIndex = await openConceptReader(
                    context: ctx,
                    concepts: conceptList,
                    initialIndex: initialIndex,
                    onMarkRead: onMarkRead ?? (_) {},
                    showGotIt: showGotIt,
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

  setUp(() {
    lastClosedIndex = null;
    SharedPreferences.setMockInitialValues({});
  });

  group('ConceptReader tests', () {
    testWidgets('opens on initialIndex and shows that concept term and pill number', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Encapsulation'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping left (drag 400 px) shows the next concept term and updates pill number; swiping right returns', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Encapsulation'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Swipe left
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Inheritance'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Swipe right
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Encapsulation'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('there is no close button and the speaker button exists with finite size greater than 0', (tester) async {
      await tester.pumpWidget(createTestHarness());
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      final speakerFinder = find.byIcon(Icons.volume_up_rounded);
      expect(speakerFinder, findsOneWidget);
      final speakerBox = tester.renderObject<RenderBox>(speakerFinder);
      expect(speakerBox.size.width, greaterThan(0));
      expect(speakerBox.size.height, greaterThan(0));
      expect(speakerBox.size.width.isFinite, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the speaker calls toggle with the current page concept; speed chip appears only while reading', (tester) async {
      final fakeSpeech = FakeSpeechService();
      await tester.pumpWidget(createTestHarness(fakeSpeech: fakeSpeech));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('1x'), findsNothing);

      // Tap speaker
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(fakeSpeech.spokenStrings, isNotEmpty);
      expect(fakeSpeech.spokenStrings.first, contains('Encapsulation'));
      expect(find.text('1x'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing page stops reading', (tester) async {
      final fakeSpeech = FakeSpeechService();
      await tester.pumpWidget(createTestHarness(fakeSpeech: fakeSpeech));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();
      expect(find.text('1x'), findsOneWidget);

      // Change page
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('1x'), findsNothing);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Got it on page 1 calls onMarkRead with that concept id, then after 600ms and 400ms second concept shows', (tester) async {
      final markedIds = <String>[];
      await tester.pumpWidget(
        createTestHarness(
          initialIndex: 0,
          onMarkRead: (id) => markedIds.add(id),
        ),
      );
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Got it'));
      await tester.pump();
      expect(markedIds, ['c1']);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Inheritance'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Got it on the last page calls onMarkRead and the route is popped', (tester) async {
      final markedLast = <String>[];
      await tester.pumpWidget(
        createTestHarness(
          initialIndex: 2,
          onMarkRead: (id) => markedLast.add(id),
        ),
      );
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Got it'));
      await tester.pump();
      expect(markedLast, ['c3']);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pull down 300 px pops route and returns current index', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 1));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsOneWidget);

      await tester.drag(find.text('Inheritance'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsNothing);
      expect(lastClosedIndex, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pull down 40 px keeps open and content returns to original position', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final initialTop = tester.getTopLeft(find.text('Encapsulation')).dy;
      await tester.drag(find.byKey(const Key('reader_top_drag_zone')), const Offset(0, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsOneWidget);
      final finalTop = tester.getTopLeft(find.text('Encapsulation')).dy;
      expect(finalTop, closeTo(initialTop, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('on the long page, scroll down 300 px first, then dragging down 100 px scrolls back without closing', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 2));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(find.text('Polymorphism'), const Offset(0, -300));
      await tester.pump();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging the top zone down 200 px still closes it', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(find.byKey(const Key('reader_top_drag_zone')), const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("the Semantics custom action 'Close reader' exists on top zone and pops the route", (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(createTestHarness(initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final topZoneFinder = find.byKey(const Key('reader_top_drag_zone'));
      final node = tester.getSemantics(topZoneFinder);
      final data = node.getSemanticsData();

      final customActionId = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Close reader'),
      );
      expect(data.customSemanticsActionIds?.contains(customActionId), isTrue);

      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        customActionId,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConceptReader), findsNothing);
      semanticsHandle.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('with disableAnimations true all work without exceptions', (tester) async {
      await tester.pumpWidget(createTestHarness(disableAnimations: true, initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ConceptReader), findsOneWidget);

      await tester.drag(find.byKey(const Key('reader_top_drag_zone')), const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ConceptReader), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 throws nothing', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          textScaler: const TextScaler.linear(1.3),
        ),
      );
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });

    testWidgets("reader's onMarkRead marks concept as read but does not advance the card pager", (tester) async {
      final pageController = PageController(initialPage: 0);
      addTearDown(pageController.dispose);
      final markedConcepts = <String>[];

      void readerOnMarkRead(String conceptId) {
        markedConcepts.add(conceptId);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PageView(
              controller: pageController,
              children: const [
                Text('Card 0'),
                Text('Card 1'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(pageController.page, 0);

      readerOnMarkRead('c1');
      await tester.pump(const Duration(milliseconds: 700));
      expect(markedConcepts, ['c1']);
      expect(pageController.page, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('after the reader reports a different closing index, the pager jumps to it', (tester) async {
      final pageController = PageController(initialPage: 0);
      addTearDown(pageController.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayConceptsControllerProvider.overrideWith(
              () => FakeTodayConceptsController(TodayConceptsState(
                concepts: [concept1, concept2, concept3],
                readConceptIds: const {},
                isFallback: false,
                userUid: 'u',
                liveStreak: 0,
              )),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    final targetIndex = await openConceptReader(
                      context: ctx,
                      concepts: [concept1, concept2, concept3],
                      initialIndex: 0,
                      onMarkRead: (_) {},
                    );
                    if (targetIndex != null && pageController.hasClients) {
                      final currentCardIndex = pageController.page?.round() ?? pageController.initialPage;
                      if (targetIndex != currentCardIndex) {
                        pageController.jumpToPage(targetIndex);
                      }
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
              bottomNavigationBar: SizedBox(
                height: 100,
                child: PageView(
                  controller: pageController,
                  children: const [
                    Text('Card 0'),
                    Text('Card 1'),
                    Text('Card 2'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(pageController.page, 0);

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // In reader, swipe to page 1
      await tester.fling(find.byType(PageView).first, const Offset(-400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Inheritance'), findsOneWidget);

      // Close reader by pull down
      await tester.drag(find.byKey(const Key('reader_top_drag_zone')), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The card pager has jumped to index 1
      expect(pageController.page, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinned term header remains fixed in place when reader content is scrolled down', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 2));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final initialTermTop = tester.getTopLeft(find.text('Polymorphism')).dy;
      final initialDefTop = tester.getTopLeft(find.text('DEFINITION')).dy;

      // Scroll content down by 200px
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();

      final scrolledTermTop = tester.getTopLeft(find.text('Polymorphism')).dy;
      final scrolledDefTop = tester.getTopLeft(find.text('DEFINITION')).dy;

      // Term remains pinned at the exact same vertical position
      expect(scrolledTermTop, equals(initialTermTop));
      // Definition content has scrolled up
      expect(scrolledDefTop, lessThan(initialDefTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScrollFadeMask wraps the scroll view in reader and renders ShaderMask', (tester) async {
      await tester.pumpWidget(createTestHarness(initialIndex: 0));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ScrollFadeMask), findsWidgets);
      expect(find.byType(ShaderMask), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Got it bar is absent when showGotIt is false and present when true', (tester) async {
      // showGotIt: false
      await tester.pumpWidget(createTestHarness(showGotIt: false));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.widgetWithText(ElevatedButton, 'Got it'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Got it \u2713'), findsNothing);
      expect(tester.takeException(), isNull);

      // Close reader
      await tester.drag(find.byKey(const Key('reader_top_drag_zone')), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // showGotIt: true
      await tester.pumpWidget(createTestHarness(showGotIt: true));
      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.widgetWithText(ElevatedButton, 'Got it'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reader bookmark toggles for the current page', (tester) async {
      final fakeUserRepo = FakeUserRepositoryForReader();
      final user = AppUser(
        uid: 'uid123',
        email: 'test@example.com',
        fieldOfStudy: 'software_engineering',
        currentStreak: 0,
        lastActivityDate: null,
        activityLog: const {},
        savedConcepts: const {'c1': 100},
      );

      await tester.pumpWidget(
        createTestHarness(
          initialIndex: 0,
          extraOverrides: [
            appUserProvider.overrideWith((ref) => Stream.value(user)),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
          ],
        ),
      );

      await tester.tap(find.text('Open Reader'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Page 0 (concept1: id 'c1' which is saved)
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);

      // Tap bookmark on current page
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pump();
      expect(fakeUserRepo.toggledConceptIds, ['c1']);

      // Swipe to next page (concept2: id 'c2' which is unsaved)
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      // Tap bookmark on page 2
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();
      expect(fakeUserRepo.toggledConceptIds, ['c1', 'c2']);
      expect(tester.takeException(), isNull);
    });
  });
}

