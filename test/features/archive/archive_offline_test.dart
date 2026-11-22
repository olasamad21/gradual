import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/services/offline_content_cache.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/core/utils/date_utils.dart';
import 'package:gradual/features/archive/archive_data.dart';
import 'package:gradual/features/archive/archive_screen.dart';
import 'package:gradual/features/daily_word/concept_providers.dart';
import 'package:gradual/features/daily_word/today_header.dart';

Concept _c(String id, String term, String category) => Concept(
      id: id,
      term: term,
      category: category,
      level: 'beginner',
      definition: '$term explained.',
      summary: '$term in one line.',
      realWorldExample: 'Example.',
      related: const [],
      quiz: const ConceptQuiz(question: 'Q', options: ['A', 'B'], answerIndex: 0, explanation: ''),
    );

final _sql = _c('sql', 'SQL vs NoSQL', 'databases');
final _pk = _c('pk', 'Primary Key', 'databases');
final _mutex = _c('mutex', 'Mutex', 'synchronization');

AppUser _user(Map<String, dynamic> log) => AppUser(
      uid: 'u1',
      email: 'a@b.com',
      fieldOfStudy: 'software_engineering',
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
      rawActivityLog: log,
    );

class _Content implements ContentRepository {
  _Content();

  bool fail = false;
  final List<String> fetchedDates = [];

  @override
  Future<List<Concept>> getConceptsByIds(String fieldOfStudy, List<String> ids) async {
    if (fail) throw Exception('offline');
    return [for (final c in [_sql, _pk, _mutex]) if (ids.contains(c.id)) c];
  }

  @override
  Future<TodaysConceptsResult> getTodaysConcepts(String fieldOfStudy, String dateId) async {
    if (fail) throw Exception('offline');
    fetchedDates.add(dateId);
    return TodaysConceptsResult(concepts: [_sql, _pk]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final log = <String, dynamic>{
    '2026-11-17': {'concepts_read': ['mutex']},
    '2026-11-24': {'concepts_read': ['sql', 'mutex']},
    '2026-11-25': {'concepts_read': ['pk']},
    'not-a-date': {'concepts_read': ['x']},
  };

  group('archive data', () {
    test('firstReadDates keeps the first day each word was read', () {
      final first = firstReadDates(log);
      expect(first, {
        'mutex': DateTime(2026, 11, 17),
        'sql': DateTime(2026, 11, 24),
        'pk': DateTime(2026, 11, 25),
      });
    });

    test('groupByWeek puts newest week first with words in reading order', () {
      final weeks = groupByWeek([_pk, _mutex, _sql], firstReadDates(log));
      expect(weeks.map((w) => w.monday), [DateTime(2026, 11, 23), DateTime(2026, 11, 16)]);
      expect(weeks.first.concepts.map((c) => c.id), ['sql', 'pk']);
      expect(weeks.first.topics, ['Databases']);
      expect(weeks.first.label, '23 – 29 Nov');
      expect(ArchiveWeek(monday: DateTime(2026, 11, 30), concepts: const []).label, '30 Nov – 6 Dec');
    });
  });

  testWidgets('archive screen groups words by week and searches them', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      appUserProvider.overrideWith((ref) => Stream.value(_user(log))),
      contentRepositoryProvider.overrideWithValue(_Content()),
    ]);
    addTearDown(container.dispose);
    container.listen(appUserProvider, (_, _) {});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const ArchiveScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 words learned'), findsOneWidget);
    expect(find.text('23 – 29 NOV'), findsOneWidget);
    expect(find.text('16 – 22 NOV'), findsOneWidget);
    expect(find.text('Primary Key'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mutex');
    await tester.pumpAndSettle();
    expect(find.text('Mutex'), findsOneWidget);
    expect(find.text('Primary Key'), findsNothing);
    expect(find.text('23 – 29 NOV'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No words match "zzz"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('OfflineContentCache', () {
    test('saves and loads a day, marking it as cached', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OfflineContentCache();
      await cache.save('2026-11-25', TodaysConceptsResult(concepts: [_sql, _pk], isWeekendReview: true));
      final loaded = await cache.load('2026-11-25');
      expect(loaded!.concepts.map((c) => c.term), ['SQL vs NoSQL', 'Primary Key']);
      expect(loaded.concepts.first.summary, 'SQL vs NoSQL in one line.');
      expect(loaded.isWeekendReview, isTrue);
      expect(loaded.fromCache, isTrue);
      expect(await cache.load('2026-11-26'), isNull);
    });

    test('keeps only the newest 21 days and tracks real versus fallback days', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OfflineContentCache();
      for (var d = 1; d <= 25; d++) {
        await cache.save('2026-11-${d.toString().padLeft(2, '0')}', TodaysConceptsResult(concepts: [_sql]));
      }
      expect(await cache.load('2026-11-04'), isNull);
      expect(await cache.load('2026-11-05'), isNotNull);
      await cache.save('2026-11-26', TodaysConceptsResult(concepts: [_sql], isFallback: true));
      expect(await cache.hasScheduled('2026-11-25'), isTrue);
      expect(await cache.hasScheduled('2026-11-26'), isFalse);
    });
  });

  group('offline Today', () {
    test("falls back to the saved copy when the network fails, and stores fresh results", () async {
      SharedPreferences.setMockInitialValues({});
      final content = _Content();
      ProviderContainer make() {
        final c = ProviderContainer(overrides: [
          appUserProvider.overrideWith((ref) => Stream.value(_user(const {}))),
          contentRepositoryProvider.overrideWithValue(content),
        ]);
        c.listen(appUserProvider, (_, _) {});
        c.listen(todaysConceptsProvider, (_, _) {});
        return c;
      }

      final online = make();
      await online.read(appUserProvider.future);
      final fresh = await online.read(todaysConceptsProvider.future);
      expect(fresh.fromCache, isFalse);
      online.dispose();
      await Future<void>.delayed(Duration.zero);

      content.fail = true;
      final offline = make();
      addTearDown(offline.dispose);
      await offline.read(appUserProvider.future);
      final cached = await offline.read(todaysConceptsProvider.future);
      expect(cached.fromCache, isTrue);
      expect(cached.concepts.map((c) => c.id), ['sql', 'pk']);
    });

    test('prefetch stores the next seven days and skips days already saved', () async {
      SharedPreferences.setMockInitialValues({});
      final content = _Content();
      final container = ProviderContainer(overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(_user(const {}))),
        contentRepositoryProvider.overrideWithValue(content),
      ]);
      addTearDown(container.dispose);
      container.listen(appUserProvider, (_, _) {});
      await container.read(appUserProvider.future);

      await container.read(contentPrefetcherProvider)();
      expect(content.fetchedDates, hasLength(7));
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(await container.read(offlineContentCacheProvider).load(DateUtilsGradual.localDateId(tomorrow)), isNotNull);

      await container.read(contentPrefetcherProvider)();
      expect(content.fetchedDates, hasLength(7));
    });
  });

  testWidgets('Today header shows an Offline chip when using the saved copy', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TodayHeader(
          greeting: 'Good morning',
          firstName: 'Ada',
          streak: 2,
          readCount: 0,
          total: 3,
          rawActivityLog: const {},
          today: DateTime(2026, 11, 25),
          isOffline: true,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Offline'), findsOneWidget);
  });
}
