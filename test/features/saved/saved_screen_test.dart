import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/repositories/user_repository.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/concept_reader.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';
import 'package:gradual/features/quiz/quiz_models.dart';
import 'package:gradual/features/quiz/quiz_providers.dart';
import 'package:gradual/features/saved/saved_screen.dart';
import 'package:gradual/shared/widgets/app_shell.dart';

class FakeContentRepository implements ContentRepository {
  bool shouldThrow = false;
  int getConceptsCallCount = 0;
  final Map<String, Concept> conceptStore = {};

  @override
  Future<List<Concept>> getConceptsByIds(String fieldOfStudy, List<String> ids) async {
    getConceptsCallCount++;
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return ids.where((id) => conceptStore.containsKey(id)).map((id) => conceptStore[id]!).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserRepository implements UserRepository {
  final StreamController<AppUser?> userStreamController = StreamController<AppUser?>.broadcast();
  AppUser? currentUser;
  int setConceptSavedCalls = 0;
  final List<Map<String, dynamic>> savedCallLog = [];

  void emitUser(AppUser? user) {
    currentUser = user;
    userStreamController.add(user);
  }

  @override
  Future<void> setConceptSaved({
    required String uid,
    required String conceptId,
    required bool saved,
    required int savedAtMillis,
  }) async {
    setConceptSavedCalls++;
    savedCallLog.add({
      'uid': uid,
      'conceptId': conceptId,
      'saved': saved,
      'savedAtMillis': savedAtMillis,
    });
    if (currentUser != null) {
      final updatedSaved = Map<String, int>.from(currentUser!.savedConcepts);
      if (saved) {
        updatedSaved[conceptId] = savedAtMillis;
      } else {
        updatedSaved.remove(conceptId);
      }
      final updatedUser = currentUser!.copyWith(savedConcepts: updatedSaved);
      emitUser(updatedUser);
    }
  }

  @override
  Stream<AppUser?> userStream(String uid) => userStreamController.stream;

  @override
  Future<AppUser?> getUser(String uid) async => currentUser;

  @override
  Future<void> createOrUpdateUser(AppUser user) async {}

  @override
  Future<void> initNewUserIfMissing(String uid) async {}

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

class FakeTodayConceptsController extends TodayConceptsController {
  FakeTodayConceptsController(this._fakeState);
  final TodayConceptsState _fakeState;

  @override
  Future<TodayConceptsState> build() async => _fakeState;
}

void main() {
  final fakeState = TodayConceptsState(
    concepts: [],
    readConceptIds: {},
    isFallback: false,
    userUid: 'u1',
    liveStreak: 0,
  );

  Concept makeConcept({
    required String id,
    required String term,
    required String definition,
    required String category,
  }) {
    return Concept(
      id: id,
      term: term,
      category: category,
      definition: definition,
      level: 'beginner',
      analogy: 'Analogy for $term',
      realWorldExample: 'Example for $term',
      confusedWith: null,
      related: const ['OOP'],
      quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
    );
  }

  final concept1 = makeConcept(
    id: 'c1',
    term: 'Encapsulation',
    category: 'oop',
    definition: 'Bundling data and methods that operate on that data.',
  );

  final concept2 = makeConcept(
    id: 'c2',
    term: 'Polymorphism',
    category: 'oop',
    definition: 'Provision of a single interface to entities of different types.',
  );

  final concept3 = makeConcept(
    id: 'c3',
    term: 'Inheritance',
    category: 'oop',
    definition: 'Acquiring properties and behaviors from a parent.',
  );

  final concept4 = makeConcept(
    id: 'c4',
    term: 'Binary Search',
    category: 'algorithms',
    definition: 'Efficient algorithm to find an item in an ordered array.',
  );

  final concept5 = makeConcept(
    id: 'c5',
    term: 'Quick Sort',
    category: 'algorithms',
    definition: 'Divide and conquer sorting using a pivot element.',
  );

  final concept6 = makeConcept(
    id: 'c6',
    term: 'Merge Sort',
    category: 'algorithms',
    definition: 'Stable divide and conquer sorting algorithm.',
  );

  AppUser createTestUser({Map<String, int> savedConcepts = const {}}) {
    return AppUser(
      uid: 'u1',
      email: 'test@example.com',
      fieldOfStudy: 'software_engineering',
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
      savedConcepts: savedConcepts,
    );
  }

  ProviderContainer makeTestContainer({
    required FakeUserRepository fakeUserRepo,
    required FakeContentRepository fakeContentRepo,
  }) {
    return ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => fakeUserRepo.userStreamController.stream),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
        contentRepositoryProvider.overrideWithValue(fakeContentRepo),
        todayConceptsControllerProvider.overrideWith(() => FakeTodayConceptsController(fakeState)),
        todayProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12, 0)),
      ],
    );
  }

  Widget createTestWidget({
    required Widget child,
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }

  testWidgets('SavedScreen shows the empty state when no words are saved', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository();
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {}));
    await tester.pump();

    expect(find.text('No saved words yet'), findsOneWidget);
    expect(find.text('Tap the bookmark on any card to keep it here.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SavedScreen shows rows newest first and row tap opens reader without Got it button', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 100, 'c2': 200}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Polymorphism'), findsOneWidget);
    expect(find.text('Encapsulation'), findsOneWidget);

    final polyTop = tester.getTopLeft(find.text('Polymorphism')).dy;
    final encapTop = tester.getTopLeft(find.text('Encapsulation')).dy;
    expect(polyTop, lessThan(encapTop));

    await tester.tap(find.text('Polymorphism'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConceptReader), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Got it'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Got it \u2713'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unsave tap removes the row immediately and shows SnackBar', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 100, 'c2': 200}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Polymorphism'), findsOneWidget);
    expect(find.text('Encapsulation'), findsOneWidget);

    final bookmarkButtons = find.byTooltip('Remove from saved');
    expect(bookmarkButtons, findsNWidgets(2));
    await tester.tap(bookmarkButtons.first);
    await tester.pump();

    expect(find.text('Polymorphism'), findsNothing);
    expect(find.text('Encapsulation'), findsOneWidget);
    expect(find.text('Removed from saved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error state shows Retry with finite width greater than 0 and tapping it triggers reload', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..shouldThrow = true
      ..conceptStore['c1'] = concept1;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 100}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Failed to load saved words.'), findsOneWidget);
    final retryFinder = find.widgetWithText(ElevatedButton, 'Retry');
    expect(retryFinder, findsOneWidget);

    final box = tester.renderObject<RenderBox>(retryFinder);
    expect(box.size.width.isFinite, isTrue);
    expect(box.size.width, greaterThan(0));
    expect(box.size.height, 48);

    fakeContent.shouldThrow = false;
    await tester.tap(retryFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Encapsulation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search field and chips and count text render with 6 concepts across 2 categories', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2
      ..conceptStore['c3'] = concept3
      ..conceptStore['c4'] = concept4
      ..conceptStore['c5'] = concept5
      ..conceptStore['c6'] = concept6;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {
      'c1': 10,
      'c2': 20,
      'c3': 30,
      'c4': 40,
      'c5': 50,
      'c6': 60,
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(TextField, 'Search saved words'), findsOneWidget);
    expect(find.text('6 saved words'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Algorithms'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Oop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing a term shows only matching rows and the count reads N of M', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2
      ..conceptStore['c3'] = concept3
      ..conceptStore['c4'] = concept4
      ..conceptStore['c5'] = concept5
      ..conceptStore['c6'] = concept6;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {
      'c1': 10,
      'c2': 20,
      'c3': 30,
      'c4': 40,
      'c5': 50,
      'c6': 60,
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'Sort');
    await tester.pump();

    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('Quick Sort'), findsOneWidget);
    expect(find.text('Merge Sort'), findsOneWidget);
    expect(find.text('Binary Search'), findsNothing);
    expect(find.text('Encapsulation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the clear button empties the query and restores all rows', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2
      ..conceptStore['c3'] = concept3
      ..conceptStore['c4'] = concept4
      ..conceptStore['c5'] = concept5
      ..conceptStore['c6'] = concept6;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {
      'c1': 10,
      'c2': 20,
      'c3': 30,
      'c4': 40,
      'c5': 50,
      'c6': 60,
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'Sort');
    await tester.pump();
    expect(find.text('2 of 6'), findsOneWidget);

    final clearButton = find.byTooltip('Clear search');
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pump();

    expect(find.text('6 saved words'), findsOneWidget);
    expect(find.text('Binary Search'), findsOneWidget);
    // Rows are cards now, so the last one may sit below the test viewport.
    await tester.scrollUntilVisible(find.text('Encapsulation'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Encapsulation'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a category chip filters and tapping it again clears it', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2
      ..conceptStore['c3'] = concept3
      ..conceptStore['c4'] = concept4
      ..conceptStore['c5'] = concept5
      ..conceptStore['c6'] = concept6;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {
      'c1': 10,
      'c2': 20,
      'c3': 30,
      'c4': 40,
      'c5': 50,
      'c6': 60,
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Algorithms'));
    await tester.pump();

    expect(find.text('3 of 6'), findsOneWidget);
    expect(find.text('Binary Search'), findsOneWidget);
    expect(find.text('Quick Sort'), findsOneWidget);
    expect(find.text('Merge Sort'), findsOneWidget);
    expect(find.text('Encapsulation'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Algorithms'));
    await tester.pump();

    expect(find.text('6 saved words'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Encapsulation'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Encapsulation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chips row is hidden with a single category', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 10, 'c2': 20}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ChoiceChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching sort to A to Z reorders the rows', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c4'] = concept4;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c4': 100, 'c1': 200}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    var encapTop = tester.getTopLeft(find.text('Encapsulation')).dy;
    var binaryTop = tester.getTopLeft(find.text('Binary Search')).dy;
    expect(encapTop, lessThan(binaryTop));

    await tester.tap(find.text('Newest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('A to Z').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    encapTop = tester.getTopLeft(find.text('Encapsulation')).dy;
    binaryTop = tester.getTopLeft(find.text('Binary Search')).dy;
    expect(binaryTop, lessThan(encapTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no-results state shows the message and Clear filters restores the list', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 100}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();

    expect(find.text('No results for "xyz"'), findsOneWidget);
    final clearFiltersFinder = find.widgetWithText(TextButton, 'Clear filters');
    expect(clearFiltersFinder, findsOneWidget);

    await tester.tap(clearFiltersFinder);
    await tester.pump();

    expect(find.text('Encapsulation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row opens the reader on the filtered list', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c5'] = concept5
      ..conceptStore['c6'] = concept6;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c5': 10, 'c6': 20}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), 'Quick');
    await tester.pump();

    await tester.tap(find.text('Quick Sort'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConceptReader), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Got it'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping trailing bookmark removes row and Undo calls restore with original millis', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        container: container,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 55555}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pump();

    expect(find.text('Encapsulation'), findsNothing);

    // Allow SnackBar to slide in
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Removed from saved'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(fakeUser.savedCallLog.length, 2);
    expect(fakeUser.savedCallLog[0]['saved'], isFalse);
    expect(fakeUser.savedCallLog[1]['saved'], isTrue);
    expect(fakeUser.savedCallLog[1]['conceptId'], 'c1');
    expect(fakeUser.savedCallLog[1]['savedAtMillis'], 55555);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping a row left removes it and offers Undo', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(createTestWidget(child: const SavedScreen(), container: container));
    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 1, 'c2': 2}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(find.text('Encapsulation'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Encapsulation'), findsNothing);
    expect(find.text('Polymorphism'), findsOneWidget);
    expect(find.text('Removed from saved'), findsOneWidget);
    expect(fakeUser.savedCallLog.single['conceptId'], 'c1');
    expect(fakeUser.savedCallLog.single['saved'], isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows show the summary and topic instead of the full definition', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()..conceptStore['c4'] = concept4;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(createTestWidget(child: const SavedScreen(), container: container));
    fakeUser.emitUser(createTestUser(savedConcepts: {'c4': 1}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Efficient algorithm to find an item in an ordered array.'), findsOneWidget);
    expect(find.text('Algorithms · Beginner'), findsOneWidget);
  });

  testWidgets('text scale 1.3 throws nothing, all rows fit, and tappable controls have finite width > 0', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c4'] = concept4;
    final container = makeTestContainer(fakeUserRepo: fakeUser, fakeContentRepo: fakeContent);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
            ),
            child: const SavedScreen(),
          ),
        ),
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 10, 'c4': 20}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final bookmarkButtons = find.byTooltip('Remove from saved');
    expect(bookmarkButtons, findsNWidgets(2));
    for (final btn in bookmarkButtons.evaluate()) {
      final box = btn.renderObject as RenderBox;
      expect(box.size.width.isFinite, isTrue);
      expect(box.size.width, greaterThan(0));
      expect(box.size.height.isFinite, isTrue);
      expect(box.size.height, greaterThan(0));
    }

    final sortBtn = find.text('Newest');
    expect(sortBtn, findsOneWidget);
    final sortBox = tester.renderObject<RenderBox>(sortBtn);
    expect(sortBox.size.width.isFinite, isTrue);
    expect(sortBox.size.width, greaterThan(0));

    expect(tester.takeException(), isNull);
  });

  testWidgets('app shell shows four destinations in the order Today, Quiz, Saved, Profile and tapping Saved shows SavedScreen', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository();

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => fakeUser.userStreamController.stream),
        userRepositoryProvider.overrideWithValue(fakeUser),
        contentRepositoryProvider.overrideWithValue(fakeContent),
        todayConceptsControllerProvider.overrideWith(() => FakeTodayConceptsController(fakeState)),
        quizButtonStateProvider.overrideWith((ref, date) => const QuizButtonState(
              'Quiz',
              false,
              false,
            )),
        todayProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12, 0)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(),
        ),
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {}));
    await tester.pump();

    final destinations = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).toList();
    expect(destinations.length, 4);
    expect(destinations[0].label, 'Today');
    expect(destinations[1].label, 'Quiz');
    expect(destinations[2].label, 'Saved');
    expect(destinations[3].label, 'Profile');

    await tester.tap(find.text('Saved'));
    await tester.pump();

    expect(find.byType(SavedScreen), findsOneWidget);
    expect(find.text('No saved words yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
