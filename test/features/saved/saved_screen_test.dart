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
  final concept1 = Concept(
    id: 'c1',
    term: 'Encapsulation',
    category: 'oop',
    definition: 'Bundling data and methods that operate on that data.',
    level: 'beginner',
    analogy: 'A medicine capsule.',
    realWorldExample: 'Private class fields.',
    confusedWith: 'Abstraction',
    related: const ['OOP'],
    quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
  );

  final concept2 = Concept(
    id: 'c2',
    term: 'Polymorphism',
    category: 'software-engineering',
    definition: 'Provision of a single interface to entities of different types.',
    level: 'beginner',
    analogy: 'Universal remote.',
    realWorldExample: 'Method overriding.',
    confusedWith: 'Overloading',
    related: const ['OOP'],
    quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
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

  Widget createTestWidget({
    required Widget child,
    required FakeUserRepository fakeUserRepo,
    required FakeContentRepository fakeContentRepo,
  }) {
    return ProviderScope(
      overrides: [
        appUserProvider.overrideWith((ref) => fakeUserRepo.userStreamController.stream),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
        contentRepositoryProvider.overrideWithValue(fakeContentRepo),
        todayProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12, 0)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
      ),
    );
  }

  testWidgets('SavedScreen shows the empty state when no words are saved', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository();

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        fakeUserRepo: fakeUser,
        fakeContentRepo: fakeContent,
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

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        fakeUserRepo: fakeUser,
        fakeContentRepo: fakeContent,
      ),
    );

    // c2 is newer (200) than c1 (100)
    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 100, 'c2': 200}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Polymorphism'), findsOneWidget);
    expect(find.text('Encapsulation'), findsOneWidget);

    // Verify ordering: Polymorphism appears above Encapsulation
    final polyTop = tester.getTopLeft(find.text('Polymorphism')).dy;
    final encapTop = tester.getTopLeft(find.text('Encapsulation')).dy;
    expect(polyTop, lessThan(encapTop));

    // Tap row opens reader without Got it button
    await tester.tap(find.text('Polymorphism'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConceptReader), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Got it'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Got it \u2713'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unsave tap removes the row immediately', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..conceptStore['c1'] = concept1
      ..conceptStore['c2'] = concept2;

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        fakeUserRepo: fakeUser,
        fakeContentRepo: fakeContent,
      ),
    );

    fakeUser.emitUser(createTestUser(savedConcepts: {'c1': 100, 'c2': 200}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Polymorphism'), findsOneWidget);
    expect(find.text('Encapsulation'), findsOneWidget);

    // Tap unsave bookmark on first row (Polymorphism)
    final bookmarkButtons = find.byTooltip('Remove from saved');
    expect(bookmarkButtons, findsNWidgets(2));
    await tester.tap(bookmarkButtons.first);
    await tester.pump();

    // Polymorphism is removed immediately
    expect(find.text('Polymorphism'), findsNothing);
    expect(find.text('Encapsulation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error state shows Retry with finite width greater than 0 and tapping it triggers reload', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository()
      ..shouldThrow = true
      ..conceptStore['c1'] = concept1;

    await tester.pumpWidget(
      createTestWidget(
        child: const SavedScreen(),
        fakeUserRepo: fakeUser,
        fakeContentRepo: fakeContent,
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

    // Fix repository and tap retry
    fakeContent.shouldThrow = false;
    await tester.tap(retryFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Encapsulation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app shell shows four destinations in the order Today, Quiz, Saved, Profile and tapping Saved shows SavedScreen', (tester) async {
    final fakeUser = FakeUserRepository();
    final fakeContent = FakeContentRepository();

    final fakeState = TodayConceptsState(
      concepts: [],
      readConceptIds: {},
      isFallback: false,
      userUid: 'u1',
      liveStreak: 0,
    );

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

    // Check NavigationBar destinations order
    final destinations = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).toList();
    expect(destinations.length, 4);
    expect(destinations[0].label, 'Today');
    expect(destinations[1].label, 'Quiz');
    expect(destinations[2].label, 'Saved');
    expect(destinations[3].label, 'Profile');

    // Tap Saved tab
    await tester.tap(find.text('Saved'));
    await tester.pump();

    expect(find.byType(SavedScreen), findsOneWidget);
    expect(find.text('No saved words yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
