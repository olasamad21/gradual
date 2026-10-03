import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradual/core/repositories/user_repository.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/features/quiz/quiz_models.dart';
import 'package:gradual/features/quiz/quiz_providers.dart';
import 'package:gradual/features/quiz/quiz_result_cache_provider.dart';
import 'package:gradual/core/firebase/firebase_providers.dart';

class FakeUserRepository implements UserRepository {
  int calls = 0;
  QuizSaveResult nextResult = QuizSaveResult.saved;
  Completer<QuizSaveResult>? completer;
  bool throwException = false;
  QuizResultCacheService? cache;
  bool pendingSeenDuringCall = false;

  @override
  Future<AppUser?> getUser(String uid) async => null;

  @override
  Future<void> createOrUpdateUser(AppUser user) async {}

  @override
  Future<void> initNewUserIfMissing(String uid) async {}

  @override
  Stream<AppUser?> userStream(String uid) => Stream.value(null);

  @override
  Future<void> recordConceptRead(
      {required String uid,
      required String conceptId,
      required String dateId}) async {}

  @override
  Future<void> resetStatsIfNeeded(String uid) async {}

  @override
  Future<QuizSaveResult> saveQuizScore({
    required String uid,
    required String dateId,
    required int score,
    required int total,
    required String tier,
  }) async {
    calls++;
    if (throwException) throw Exception('Network error');

    if (cache != null) {
      final pending = await cache!.loadPending(dateId);
      pendingSeenDuringCall = pending != null;
    }

    if (completer != null) {
      return completer!.future;
    }
    return nextResult;
  }
}

final fixedDate = DateTime(2026, 10, 10);
const fixedSessionId = '2026-10-10';

final testAnswers = [
  QuizAnswer(
    question: QuizQuestion(
        id: 'q1',
        text: 'Q1',
        options: ['A'],
        correctIndex: 0,
        explanation: '',
        sourceWord: '',
        type: 'mcq'),
    selectedIndex: 0,
  )
];

final testUser = AppUser(
  uid: 'u1',
  email: 'test@test.com',
  fieldOfStudy: 'CS',
  currentStreak: 0,
  lastActivityDate: null,
  activityLog: const {},
  rawActivityLog: const {},
);

Future<ProviderContainer> makeContainer({
  required AppUser? user,
  required FakeUserRepository repo,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      appUserProvider.overrideWith((ref) => Stream.value(user)),
    ],
  );
  addTearDown(container.dispose);

  container.listen(appUserProvider, (previous, next) {});
  await container.read(appUserProvider.future);

  container.listen(quizControllerProvider, (previous, next) {});
  await container.read(quizControllerProvider.future);

  repo.cache = container.read(quizResultCacheProvider);
  return container;
}

void main() {
  test('saved', () async {
    final repo = FakeUserRepository();
    final container = await makeContainer(user: testUser, repo: repo);
    final controller = container.read(quizControllerProvider.notifier);

    final result = await controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);

    expect(result, QuizSaveResult.saved);
    expect(repo.calls, 1);
    expect(repo.pendingSeenDuringCall, isTrue);

    final cache = container.read(quizResultCacheProvider);
    final pending = await cache.loadPending(fixedSessionId);
    expect(pending, isNull);
    
    final normal = await cache.loadAnswers(fixedSessionId);
    expect(normal, isNotNull);
  });

  test('alreadyTaken', () async {
    final repo = FakeUserRepository()..nextResult = QuizSaveResult.alreadyTaken;
    final container = await makeContainer(user: testUser, repo: repo);
    final controller = container.read(quizControllerProvider.notifier);

    final result = await controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);

    expect(result, QuizSaveResult.alreadyTaken);

    final cache = container.read(quizResultCacheProvider);
    expect(await cache.loadPending(fixedSessionId), isNull);
    expect(await cache.loadAnswers(fixedSessionId), isNull);
  });

  test('failed', () async {
    final repo = FakeUserRepository()..throwException = true;
    final container = await makeContainer(user: testUser, repo: repo);
    final controller = container.read(quizControllerProvider.notifier);

    final result = await controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);

    expect(result, QuizSaveResult.failed);

    final cache = container.read(quizResultCacheProvider);
    expect(await cache.loadPending(fixedSessionId), isNotNull);

    final state = container.read(quizControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.hasError, isFalse);
    expect(state.value!.submitFailed, isTrue);
    expect(state.value!.answers, isNotEmpty);
  });

  test('failed then retry', () async {
    final repo = FakeUserRepository()..throwException = true;
    final container = await makeContainer(user: testUser, repo: repo);
    final controller = container.read(quizControllerProvider.notifier);

    final r1 = await controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(r1, QuizSaveResult.failed);

    repo.throwException = false;
    repo.nextResult = QuizSaveResult.saved;

    final r2 = await controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(r2, QuizSaveResult.saved);
    expect(repo.calls, 2);

    final cache = container.read(quizResultCacheProvider);
    expect(await cache.loadPending(fixedSessionId), isNull);
    expect(await cache.loadAnswers(fixedSessionId), isNotNull);
  });

  test('missing user', () async {
    final repo = FakeUserRepository();
    final container = await makeContainer(user: null, repo: repo);
    final controller = container.read(quizControllerProvider.notifier);

    final result = await controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);

    expect(result, QuizSaveResult.failed);

    final cache = container.read(quizResultCacheProvider);
    expect(await cache.loadPending(fixedSessionId), isNotNull);
  });

  test('double submit', () async {
    final repo = FakeUserRepository()
      ..completer = Completer<QuizSaveResult>();
    final container = await makeContainer(user: testUser, repo: repo);
    final controller = container.read(quizControllerProvider.notifier);

    final f1 = controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    final f2 = controller.submitQuiz(
        today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);

    int loops = 0;
    while (repo.calls < 1 && loops < 50) {
      await Future<void>.delayed(Duration.zero);
      loops++;
    }
    if (repo.calls < 1) {
      fail('Repository was never called after 50 microtask pumps.');
    }

    repo.completer!.complete(QuizSaveResult.saved);

    final r1 = await f1;
    final r2 = await f2;

    expect(r1, QuizSaveResult.saved);
    expect(r2, QuizSaveResult.saved);
    expect(repo.calls, 1);
  });
}
