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

  @override
  Future<AppUser?> getUser(String uid) async => null;

  @override
  Future<void> createOrUpdateUser(AppUser user) async {}

  @override
  Future<void> initNewUserIfMissing(String uid) async {}

  @override
  Stream<AppUser?> userStream(String uid) => Stream.value(null);

  @override
  Future<void> recordConceptRead({required String uid, required String conceptId, required String dateId}) async {}

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
      expect(pending, isNotNull, reason: 'Pending answers should exist during network call');
    }

    if (completer != null) {
      return completer!.future;
    }
    return nextResult;
  }
}

void main() {
  final fixedDate = DateTime(2026, 10, 10);
  final fixedSessionId = '2026-10-10';
  final testAnswers = [
    QuizAnswer(
      question: QuizQuestion(id: 'q1', text: 'Q1', options: ['A'], correctIndex: 0, explanation: '', sourceWord: '', type: 'mcq'),
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

  test('QuizController submitQuiz flows', () async {
    SharedPreferences.setMockInitialValues({});
    final fakeRepo = FakeUserRepository();
    
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(fakeRepo),
        appUserProvider.overrideWith((ref) async* { yield testUser; }),
      ]
    );
    
    container.listen(quizControllerProvider, (_, __) {});
    await container.read(quizControllerProvider.future);
    fakeRepo.cache = container.read(quizResultCacheProvider);

    final controller = container.read(quizControllerProvider.notifier);
    
    // 1. saved
    final result = await controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(result, QuizSaveResult.saved);
    expect(fakeRepo.calls, 1);
    
    // verify normal result exists and pending is gone
    final cache = container.read(quizResultCacheProvider);
    var pending = await cache.loadPending(fixedSessionId);
    expect(pending, isNull);
    var normal = await cache.loadAnswers(fixedSessionId);
    expect(normal, isNotNull);
    
    // 2. alreadyTaken
    SharedPreferences.setMockInitialValues({});
    fakeRepo.nextResult = QuizSaveResult.alreadyTaken;
    
    final result2 = await controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(result2, QuizSaveResult.alreadyTaken);
    
    pending = await cache.loadPending(fixedSessionId);
    expect(pending, isNull);
    normal = await cache.loadAnswers(fixedSessionId);
    expect(normal, isNull); // not written
    
    // 3. failed (repository throws)
    fakeRepo.throwException = true;
    final result3 = await controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(result3, QuizSaveResult.failed);
    
    // pending kept, state is data, submitFailed true, answers kept
    pending = await cache.loadPending(fixedSessionId);
    expect(pending, isNotNull);
    
    final state3 = container.read(quizControllerProvider).value!;
    expect(state3.submitFailed, true);
    expect(state3.answers.isNotEmpty, true);
    
    // 4. failed then retry
    fakeRepo.throwException = false;
    fakeRepo.nextResult = QuizSaveResult.saved;
    fakeRepo.calls = 0;
    
    final result4 = await controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(result4, QuizSaveResult.saved);
    expect(fakeRepo.calls, 1);
    
    pending = await cache.loadPending(fixedSessionId);
    expect(pending, isNull);
    normal = await cache.loadAnswers(fixedSessionId);
    expect(normal, isNotNull);
    
    container.dispose();
  });

  test('QuizController missing user', () async {
    SharedPreferences.setMockInitialValues({});
    final fakeRepo = FakeUserRepository();
    
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(fakeRepo),
        appUserProvider.overrideWith((ref) async* { yield null; }),
      ]
    );
    
    container.listen(quizControllerProvider, (_, __) {});
    await container.read(quizControllerProvider.future);
    
    final controller = container.read(quizControllerProvider.notifier);
    
    final result = await controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    expect(result, QuizSaveResult.failed);
    
    final cache = container.read(quizResultCacheProvider);
    final pending = await cache.loadPending(fixedSessionId);
    expect(pending, isNotNull);
    
    container.dispose();
  });

  test('QuizController double submit', () async {
    SharedPreferences.setMockInitialValues({});
    final fakeRepo = FakeUserRepository();
    fakeRepo.completer = Completer<QuizSaveResult>();
    
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(fakeRepo),
        appUserProvider.overrideWith((ref) async* { yield testUser; }),
      ]
    );
    
    container.listen(quizControllerProvider, (_, __) {});
    await container.read(quizControllerProvider.future);
    fakeRepo.cache = container.read(quizResultCacheProvider);
    
    final controller = container.read(quizControllerProvider.notifier);
    
    final f1 = controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    final f2 = controller.submitQuiz(today: fixedDate, answers: testAnswers, sessionDateId: fixedSessionId);
    
    fakeRepo.completer!.complete(QuizSaveResult.saved);
    
    await f1;
    await f2;
    
    expect(fakeRepo.calls, 1);
    
    container.dispose();
  });
}
