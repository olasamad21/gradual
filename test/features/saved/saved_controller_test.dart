import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/repositories/user_repository.dart';
import 'package:gradual/features/quiz/quiz_models.dart';
import 'package:gradual/features/quiz/quiz_providers.dart';
import 'package:gradual/features/saved/saved_controller.dart';

class RecordedSavedCall {
  final String uid;
  final String conceptId;
  final bool saved;
  final int savedAtMillis;

  RecordedSavedCall({
    required this.uid,
    required this.conceptId,
    required this.saved,
    required this.savedAtMillis,
  });
}

class FakeUserRepository implements UserRepository {
  final List<RecordedSavedCall> savedCalls = [];
  bool throwException = false;

  @override
  Future<void> setConceptSaved({
    required String uid,
    required String conceptId,
    required bool saved,
    required int savedAtMillis,
  }) async {
    if (throwException) {
      throw Exception('Database write failed');
    }
    savedCalls.add(
      RecordedSavedCall(
        uid: uid,
        conceptId: conceptId,
        saved: saved,
        savedAtMillis: savedAtMillis,
      ),
    );
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

class FakeContentRepository implements ContentRepository {
  final List<List<String>> getConceptsCalls = [];

  @override
  Future<List<Concept>> getConceptsByIds(String fieldOfStudy, List<String> ids) async {
    getConceptsCalls.add(List.from(ids));
    return ids.map((id) => Concept(
      id: id,
      term: 'Term $id',
      category: 'cat',
      definition: 'Def $id',
      level: 'beginner',
      analogy: null,
      realWorldExample: '',
      confusedWith: null,
      related: const [],
      quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
    )).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final fixedDate = DateTime(2026, 10, 15, 14, 30);
  final fixedMillis = fixedDate.millisecondsSinceEpoch;

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

  test('toggle on an unsaved concept calls setConceptSaved with saved true and millis from todayProvider', () async {
    final fakeRepo = FakeUserRepository();
    final user = createTestUser(savedConcepts: {'existing': 100});

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(user)),
        todayProvider.overrideWithValue(() => fixedDate),
        userRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);

    container.read(savedControllerProvider.notifier).toggle('new_concept');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.savedCalls.length, 1);
    expect(fakeRepo.savedCalls.first.uid, 'u1');
    expect(fakeRepo.savedCalls.first.conceptId, 'new_concept');
    expect(fakeRepo.savedCalls.first.saved, isTrue);
    expect(fakeRepo.savedCalls.first.savedAtMillis, fixedMillis);
  });

  test('toggle on a saved concept calls it with saved false', () async {
    final fakeRepo = FakeUserRepository();
    final user = createTestUser(savedConcepts: {'saved_concept': 100});

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(user)),
        todayProvider.overrideWithValue(() => fixedDate),
        userRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);

    container.read(savedControllerProvider.notifier).toggle('saved_concept');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.savedCalls.length, 1);
    expect(fakeRepo.savedCalls.first.conceptId, 'saved_concept');
    expect(fakeRepo.savedCalls.first.saved, isFalse);
    expect(fakeRepo.savedCalls.first.savedAtMillis, fixedMillis);
  });

  test('with no user nothing is called', () async {
    final fakeRepo = FakeUserRepository();

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(null)),
        todayProvider.overrideWithValue(() => fixedDate),
        userRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);

    container.read(savedControllerProvider.notifier).toggle('any_concept');
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepo.savedCalls, isEmpty);
  });

  test('a repository that throws does not crash the toggle', () async {
    final fakeRepo = FakeUserRepository()..throwException = true;
    final user = createTestUser(savedConcepts: {});

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(user)),
        todayProvider.overrideWithValue(() => fixedDate),
        userRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);

    expect(() => container.read(savedControllerProvider.notifier).toggle('c1'), returnsNormally);
    await Future<void>.delayed(Duration.zero);
  });

  test('savedConceptsProvider returns [] and never calls content repository when nothing is saved', () async {
    final fakeContent = FakeContentRepository();
    final user = createTestUser(savedConcepts: {});

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(user)),
        contentRepositoryProvider.overrideWithValue(fakeContent),
      ],
    );
    addTearDown(container.dispose);

    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);

    final concepts = await container.read(savedConceptsProvider.future);
    expect(concepts, isEmpty);
    expect(fakeContent.getConceptsCalls, isEmpty);
  });

  test('with ids [b, a] it asks for them in that order', () async {
    final fakeContent = FakeContentRepository();
    final user = createTestUser(savedConcepts: {'a': 100, 'b': 200});

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(user)),
        contentRepositoryProvider.overrideWithValue(fakeContent),
      ],
    );
    addTearDown(container.dispose);

    container.listen(appUserProvider, (_, _) {});
    await container.read(appUserProvider.future);

    final ids = container.read(savedIdsProvider);
    expect(ids, ['b', 'a']);

    final concepts = await container.read(savedConceptsProvider.future);
    expect(concepts.map((c) => c.id).toList(), ['b', 'a']);
    expect(fakeContent.getConceptsCalls.length, 1);
    expect(fakeContent.getConceptsCalls.first, ['b', 'a']);
  });
}
