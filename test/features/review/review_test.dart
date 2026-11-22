import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/review_item.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/repositories/user_repository.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/review/review_controller.dart';
import 'package:gradual/features/review/review_engine.dart';
import 'package:gradual/features/review/review_prompt.dart';
import 'package:gradual/features/review/review_session_screen.dart';

final _now = DateTime(2026, 11, 25, 10); // Wednesday
int _ms(DateTime d) => d.millisecondsSinceEpoch;

AppUser _user({Map<String, int> saved = const {}, Map<String, ReviewItem> items = const {}}) => AppUser(
      uid: 'u1',
      email: 'a@b.com',
      fieldOfStudy: 'software_engineering',
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
      savedConcepts: saved,
      reviewItems: items,
    );

Concept _concept(String id, String term) => Concept(
      id: id,
      term: term,
      category: 'databases',
      level: 'beginner',
      definition: '$term explained.',
      summary: '$term in one line.',
      realWorldExample: 'Example.',
      related: const [],
      quiz: ConceptQuiz(
        question: 'Which describes $term?',
        options: ['Right about $term', 'Wrong one', 'Also wrong', 'Not it'],
        answerIndex: 0,
        explanation: 'Because $term.',
      ),
    );

class _Repo implements UserRepository {
  final List<(String, Map<String, dynamic>?)> writes = [];

  @override
  Future<void> setReviewItem({required String uid, required String conceptId, required Map<String, dynamic>? item}) async {
    writes.add((conceptId, item));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Content implements ContentRepository {
  _Content(this.concepts);
  final List<Concept> concepts;

  @override
  Future<List<Concept>> getConceptsByIds(String fieldOfStudy, List<String> ids) async =>
      [for (final id in ids) ...concepts.where((c) => c.id == id)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('reviewQueue and dueReviews', () {
    test('a saved word becomes due the day after it was saved', () {
      final user = _user(saved: {'sql': _ms(DateTime(2026, 11, 24, 21))});
      final queue = reviewQueue(user);
      expect(queue.single.due, DateTime(2026, 11, 25));
      expect(queue.single.fromSaved, isTrue);
      expect(dueReviews(user, _now).map((e) => e.conceptId), ['sql']);
      // Saved today: not due until tomorrow.
      final fresh = _user(saved: {'sql': _ms(DateTime(2026, 11, 25, 9))});
      expect(dueReviews(fresh, _now), isEmpty);
      expect(nextReviewDate(fresh, _now), DateTime(2026, 11, 26));
    });

    test('stored progress overrides the default and missed words stay without saving', () {
      final user = _user(
        saved: {'sql': _ms(DateTime(2026, 11, 1))},
        items: {
          'sql': ReviewItem(stage: 2, dueMillis: _ms(DateTime(2026, 12, 2)), fromSaved: true),
          'cap': ReviewItem(stage: 0, dueMillis: _ms(DateTime(2026, 11, 25)), fromMissed: true),
        },
      );
      expect(dueReviews(user, _now).map((e) => e.conceptId), ['cap']);
      expect(reviewQueue(user), hasLength(2));
      expect(nextReviewDate(user, _now), DateTime(2026, 12, 2));
    });

    test('unsaving a saved-only word drops it from review', () {
      final user = _user(items: {'sql': ReviewItem(stage: 1, dueMillis: _ms(DateTime(2026, 11, 20)), fromSaved: true)});
      expect(reviewQueue(user), isEmpty);
    });
  });

  group('afterReview and afterMissed', () {
    final entry = ReviewEntry(conceptId: 'sql', stage: 0, due: DateTime(2026, 11, 25), fromSaved: true, fromMissed: false);

    test('remembering steps through 1, 3, 7, 14, 30 and 60 days', () {
      var e = entry;
      final gaps = <int>[];
      for (var i = 0; i < 7; i++) {
        final item = afterReview(e, remembered: true, now: _now);
        gaps.add(item.due.difference(DateTime(2026, 11, 25)).inDays);
        e = ReviewEntry(conceptId: 'sql', stage: item.stage, due: item.due, fromSaved: true, fromMissed: false);
      }
      expect(gaps, [3, 7, 14, 30, 60, 60, 60]);
      expect(reviewIntervalsDays, [1, 3, 7, 14, 30, 60]);
    });

    test('forgetting resets to the start and comes back tomorrow', () {
      final later = ReviewEntry(conceptId: 'sql', stage: 4, due: DateTime(2026, 11, 25), fromSaved: true, fromMissed: false);
      final item = afterReview(later, remembered: false, now: _now);
      expect(item.stage, 0);
      expect(item.due, DateTime(2026, 11, 26));
      expect(item.fromSaved, isTrue);
    });

    test('a missed quiz word is due tomorrow and keeps its saved flag', () {
      final item = afterMissed(null, isSaved: true, now: _now);
      expect(item.due, DateTime(2026, 11, 26));
      expect(item.fromMissed, isTrue);
      expect(item.fromSaved, isTrue);
    });
  });

  test('AppUser reads review_items, skips bad entries, and copyWith keeps the activity log', () {
    final user = AppUser.fromJson('u1', {
      'email': 'a@b.com',
      'activity_log': {
        '2026-11-23': {'concepts_read': ['a']},
      },
      'review_items': {
        'sql': {'stage': 2, 'due': 100, 'saved': true},
        'bad': 'oops',
        'half': {'stage': 1},
      },
    });
    expect(user.reviewItems.keys, ['sql']);
    expect(user.reviewItems['sql'], const ReviewItem(stage: 2, dueMillis: 100, fromSaved: true));
    final copy = user.copyWith(fieldOfStudy: 'data_science');
    expect(copy.rawActivityLog, isNotEmpty);
    expect(copy.reviewItems, user.reviewItems);
  });

  group('ReviewController', () {
    test('records answers and missed words on the user document', () async {
      final repo = _Repo();
      final user = _user(saved: {'sql': _ms(DateTime(2026, 11, 20))});
      final container = ProviderContainer(overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(user)),
        userRepositoryProvider.overrideWithValue(repo),
        reviewClockProvider.overrideWithValue(() => _now),
      ]);
      addTearDown(container.dispose);
      // Riverpod pauses providers nobody listens to, so keep this one live.
      container.listen(appUserProvider, (_, _) {});
      await container.read(appUserProvider.future);

      final entry = container.read(reviewSummaryProvider).due.single;
      await container.read(reviewControllerProvider).recordAnswer(entry, remembered: true);
      await container.read(reviewControllerProvider).recordMissed(['cap', 'cap', 'sql', '']);

      expect(repo.writes.map((w) => w.$1), ['sql', 'cap', 'sql']);
      expect(repo.writes[0].$2!['stage'], 1);
      expect(repo.writes[0].$2!['due'], _ms(DateTime(2026, 11, 28)));
      expect(repo.writes[1].$2!['missed'], isTrue);
      expect(repo.writes[2].$2!['saved'], isTrue);
    });
  });

  test('friendlyDay names nearby days', () {
    expect(friendlyDay(DateTime(2026, 11, 26), _now), 'tomorrow');
    expect(friendlyDay(DateTime(2026, 11, 28), _now), 'Sat');
    expect(friendlyDay(DateTime(2026, 12, 12), _now), '12 Dec');
  });

  testWidgets('a session asks each word, records results and ends with a summary', (tester) async {
    final repo = _Repo();
    final user = _user(saved: {
      'sql': _ms(DateTime(2026, 11, 20)),
      'pk': _ms(DateTime(2026, 11, 21)),
    });
    final container = ProviderContainer(overrides: [
      appUserProvider.overrideWith((ref) => Stream.value(user)),
      userRepositoryProvider.overrideWithValue(repo),
      contentRepositoryProvider.overrideWithValue(_Content([_concept('sql', 'SQL vs NoSQL'), _concept('pk', 'Primary Key')])),
      reviewClockProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
    container.listen(appUserProvider, (_, _) {});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const ReviewPrompt(),
                TextButton(onPressed: () => openReviewSession(context), child: const Text('open')),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('2 words to review'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review_prompt')));
    await tester.pumpAndSettle();

    expect(find.text('SQL vs NoSQL'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.text('Right about SQL vs NoSQL'));
    await tester.pumpAndSettle();
    expect(find.text('Nice, you remembered it'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('review_next')), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('review_next')));
    await tester.pumpAndSettle();

    expect(find.text('Primary Key'), findsOneWidget);
    await tester.tap(find.text('Wrong one'));
    await tester.pumpAndSettle();
    expect(find.textContaining('come back tomorrow'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('review_next')), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('review_next')));
    await tester.pumpAndSettle();

    expect(find.text('Review done'), findsOneWidget);
    expect(find.text('You remembered 1 of 2'), findsOneWidget);
    expect(find.text('Back in 3 days'), findsOneWidget);
    expect(find.text('Back tomorrow'), findsOneWidget);
    expect(repo.writes.map((w) => (w.$1, w.$2!['stage'])), [('sql', 1), ('pk', 0)]);
    expect(tester.takeException(), isNull);
  });
}
