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
import 'package:gradual/features/saved/saved_filter.dart';

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
  final List<Map<String, dynamic>> reviewCallLog = [];

  @override
  Future<void> setReviewItem({
    required String uid,
    required String conceptId,
    required Map<String, dynamic>? item,
  }) async {
    reviewCallLog.add({'uid': uid, 'conceptId': conceptId, 'item': item});
  }

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

  group('savedViewProvider tests', () {
    test('initial state has empty query, null category, and newest sort', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(savedViewProvider);
      expect(state.query, '');
      expect(state.category, isNull);
      expect(state.sort, SavedSort.newest);
    });

    test('setQuery updates query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(savedViewProvider.notifier).setQuery('algorithms');
      expect(container.read(savedViewProvider).query, 'algorithms');
    });

    test('setCategory sets category and re-selecting it clears it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(savedViewProvider.notifier).setCategory('fruits');
      expect(container.read(savedViewProvider).category, 'fruits');

      // Re-selecting same category clears it
      container.read(savedViewProvider.notifier).setCategory('fruits');
      expect(container.read(savedViewProvider).category, isNull);

      // Selecting different category changes it
      container.read(savedViewProvider.notifier).setCategory('fruits');
      container.read(savedViewProvider.notifier).setCategory('vegetables');
      expect(container.read(savedViewProvider).category, 'vegetables');

      // Selecting null clears it
      container.read(savedViewProvider.notifier).setCategory(null);
      expect(container.read(savedViewProvider).category, isNull);
    });

    test('setSort changes sort order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(savedViewProvider.notifier).setSort(SavedSort.alphabetical);
      expect(container.read(savedViewProvider).sort, SavedSort.alphabetical);

      container.read(savedViewProvider.notifier).setSort(SavedSort.newest);
      expect(container.read(savedViewProvider).sort, SavedSort.newest);
    });

    test('reset restores initial state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(savedViewProvider.notifier);
      notifier.setQuery('test');
      notifier.setCategory('cat');
      notifier.setSort(SavedSort.alphabetical);

      notifier.reset();
      final state = container.read(savedViewProvider);
      expect(state.query, '');
      expect(state.category, isNull);
      expect(state.sort, SavedSort.newest);
    });
  });

  group('savedControllerProvider tests', () {
    test('toggle on an unsaved concept calls setConceptSaved with saved true and returns null', () async {
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

      final result = container.read(savedControllerProvider.notifier).toggle('new_concept');
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(fakeRepo.savedCalls.length, 1);
      expect(fakeRepo.savedCalls.first.uid, 'u1');
      expect(fakeRepo.savedCalls.first.conceptId, 'new_concept');
      expect(fakeRepo.savedCalls.first.saved, isTrue);
      expect(fakeRepo.savedCalls.first.savedAtMillis, fixedMillis);
    });

    test('toggle on a saved concept calls it with saved false and returns old millis', () async {
      final fakeRepo = FakeUserRepository();
      final user = createTestUser(savedConcepts: {'saved_concept': 12345});

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

      final result = container.read(savedControllerProvider.notifier).toggle('saved_concept');
      await Future<void>.delayed(Duration.zero);

      expect(result, 12345);
      expect(fakeRepo.savedCalls.length, 1);
      expect(fakeRepo.savedCalls.first.conceptId, 'saved_concept');
      expect(fakeRepo.savedCalls.first.saved, isFalse);
      expect(fakeRepo.savedCalls.first.savedAtMillis, fixedMillis);
    });

    test('restore calls setConceptSaved with the given millis and saved true', () async {
      final fakeRepo = FakeUserRepository();
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

      await container.read(savedControllerProvider.notifier).restore('restored_concept', 99999);
      expect(fakeRepo.savedCalls.length, 1);
      expect(fakeRepo.savedCalls.first.conceptId, 'restored_concept');
      expect(fakeRepo.savedCalls.first.saved, isTrue);
      expect(fakeRepo.savedCalls.first.savedAtMillis, 99999);
    });

    test('with no user nothing is called by toggle or restore', () async {
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

      final result = container.read(savedControllerProvider.notifier).toggle('any_concept');
      await container.read(savedControllerProvider.notifier).restore('any_concept', 123);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(fakeRepo.savedCalls, isEmpty);
    });

    test('a repository that throws does not crash toggle or restore', () async {
      final fakeRepo = FakeUserRepository()..throwException = true;
      final user = createTestUser(savedConcepts: {'c1': 100});

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

      expect(() async => await container.read(savedControllerProvider.notifier).restore('c1', 100), returnsNormally);
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
  });
}
