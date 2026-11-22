import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';
import 'package:gradual/features/reminders/reminder_card.dart';
import 'package:gradual/features/reminders/reminder_controller.dart';
import 'package:gradual/features/reminders/reminder_plan.dart';
import 'package:gradual/features/reminders/reminder_platform.dart';

Concept _c(String id, String term, {String? summary}) => Concept(
      id: id,
      term: term,
      category: 'databases',
      level: 'beginner',
      definition: '$term explained. More detail.',
      summary: summary ?? '$term in one line.',
      realWorldExample: 'Example.',
      related: const [],
      quiz: const ConceptQuiz(question: 'Q', options: ['A'], answerIndex: 0, explanation: ''),
    );

final _sql = _c('sql', 'SQL vs NoSQL');
final _pk = _c('pk', 'Primary Key');
final _idx = _c('idx', 'Database Index');

class FakeReminderPlatform implements ReminderPlatform {
  FakeReminderPlatform({this.grant = true, this.exact = true, this.maker = 'Google'});

  bool grant;
  bool exact;
  String maker;
  int permissionRequests = 0;
  int exactRequests = 0;
  int autostartOpens = 0;
  final List<ReminderMessage> shown = [];
  final Map<int, PlannedReminder> scheduled = {};
  final List<int> cancelled = [];

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<bool> requestExact() async {
    exactRequests++;
    exact = true;
    return exact;
  }

  @override
  Future<void> showNow(ReminderMessage message) async => shown.add(message);

  @override
  Future<String> manufacturer() async => maker;

  @override
  Future<bool> openAutostartSettings() async {
    autostartOpens++;
    return true;
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async => scheduled[reminder.id] = reminder;

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class FakeContentRepository implements ContentRepository {
  final Map<String, TodaysConceptsResult> byDate = {};

  @override
  Future<TodaysConceptsResult> getTodaysConcepts(String fieldOfStudy, String dateId) async =>
      byDate[dateId] ?? TodaysConceptsResult(concepts: [_sql], isFallback: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixedToday extends TodayConceptsController {
  FixedToday(this._state);
  final TodayConceptsState _state;

  @override
  Future<TodayConceptsState> build() async => _state;
}

void main() {
  group('buildReminderMessage', () {
    test('names the first word and its summary in the morning', () {
      final m = buildReminderMessage(DayContent(concepts: [_sql, _pk, _idx]));
      expect(m.title, 'Today: SQL vs NoSQL');
      expect(m.body, 'SQL vs NoSQL in one line.');
      expect(m.expandedBody, contains('Also today: Primary Key and Database Index.'));
    });

    test('counts what is left once some words are read', () {
      final m = buildReminderMessage(DayContent(concepts: [_sql, _pk, _idx], readIds: const {'sql'}));
      expect(m.title, '2 words left today');
      expect(m.body, startsWith('Next up: Primary Key.'));

      final last = buildReminderMessage(DayContent(concepts: [_sql, _pk, _idx], readIds: const {'sql', 'pk'}));
      expect(last.title, '1 word left today: Database Index');
      expect(last.expandedBody, contains('perfect day'));
    });

    test('uses a weekend review message on weekends', () {
      final m = buildReminderMessage(DayContent(concepts: [_sql, _pk, _idx], isWeekendReview: true));
      expect(m.title, 'Weekend review');
      expect(m.body, startsWith('3 words from this week'));
    });

    test('stays generic when the day has no scheduled words', () {
      final m = buildReminderMessage(DayContent(concepts: [_sql], isScheduled: false));
      expect(m.title, 'Your words are waiting');
      expect(m.body, isNot(contains('SQL')));
    });
  });

  group('planReminders', () {
    const on = ReminderSettings(enabled: true, hour: 9, minute: 0);
    DayContent words(DateTime _) => DayContent(concepts: [_sql, _pk, _idx]);

    test('schedules today and the next six days at the chosen time', () {
      final plan = planReminders(now: DateTime(2026, 11, 23, 7, 30), settings: on, contentFor: words);
      expect(plan, hasLength(7));
      expect(plan.first.when, DateTime(2026, 11, 23, 9, 0));
      expect(plan.last.when, DateTime(2026, 11, 29, 9, 0));
      expect(plan.map((p) => p.id).toSet(), hasLength(7));
    });

    test('skips today once the time has passed', () {
      final plan = planReminders(now: DateTime(2026, 11, 23, 9, 1), settings: on, contentFor: words);
      expect(plan, hasLength(6));
      expect(plan.first.when, DateTime(2026, 11, 24, 9, 0));
    });

    test('skips a day whose words are already all read', () {
      final plan = planReminders(
        now: DateTime(2026, 11, 23, 7, 0),
        settings: on,
        contentFor: (d) => d.day == 23
            ? DayContent(concepts: [_sql], readIds: const {'sql'})
            : DayContent(concepts: [_sql]),
      );
      expect(plan.first.when.day, 24);
    });

    test('plans nothing when reminders are off', () {
      expect(planReminders(now: DateTime(2026, 11, 23), settings: const ReminderSettings(), contentFor: words), isEmpty);
    });

    test('IDs stay the same for the same weekday', () {
      expect(reminderIdFor(DateTime(2026, 11, 23)), reminderIdFor(DateTime(2026, 11, 30)));
      expect(allReminderIds, contains(reminderIdFor(DateTime(2026, 11, 29))));
    });
  });

  group('ReminderController', () {
    late FakeReminderPlatform platform;
    late FakeContentRepository content;

    ProviderContainer make({Set<String> read = const {}}) {
      final container = ProviderContainer(overrides: [
        reminderPlatformProvider.overrideWithValue(platform),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 11, 23, 7, 0)),
        contentRepositoryProvider.overrideWithValue(content),
        appUserProvider.overrideWith((ref) => Stream.value(null)),
        todayConceptsControllerProvider.overrideWith(() => FixedToday(TodayConceptsState(
              concepts: [_sql, _pk, _idx],
              readConceptIds: read,
              isFallback: false,
              userUid: 'u1',
              liveStreak: 2,
            ))),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      platform = FakeReminderPlatform();
      content = FakeContentRepository()
        ..byDate['2026-11-24'] = TodaysConceptsResult(concepts: [_pk, _idx, _sql]);
    });

    test('starts off at 9:00 and touches nothing while off', () async {
      final container = make();
      expect(await container.read(reminderControllerProvider.future), const ReminderSettings());
      await container.read(reminderControllerProvider.notifier).sync();
      expect(platform.scheduled, isEmpty);
      expect(platform.cancelled, isEmpty);
    });

    test('turning on asks permission, saves, and schedules a week of real words', () async {
      final container = make();
      await container.read(todayConceptsControllerProvider.future);
      final ok = await container.read(reminderControllerProvider.notifier).setEnabled(true);

      expect(ok, isTrue);
      expect(platform.permissionRequests, 1);
      expect(platform.scheduled, hasLength(7));
      expect(platform.scheduled[reminderIdFor(DateTime(2026, 11, 23))]!.message.title, 'Today: SQL vs NoSQL');
      expect(platform.scheduled[reminderIdFor(DateTime(2026, 11, 24))]!.message.title, 'Today: Primary Key');
      // Days with no uploaded set yet get the generic text, not old words.
      expect(platform.scheduled[reminderIdFor(DateTime(2026, 11, 25))]!.message.title, 'Your words are waiting');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reminder_enabled'), isTrue);
    });

    test('declined permission leaves reminders off', () async {
      platform.grant = false;
      final container = make();
      final ok = await container.read(reminderControllerProvider.notifier).setEnabled(true);
      expect(ok, isFalse);
      expect(container.read(reminderControllerProvider).value?.enabled, isFalse);
      expect(platform.scheduled, isEmpty);
    });

    test('changing the time reschedules, and turning off cancels everything', () async {
      final container = make();
      await container.read(todayConceptsControllerProvider.future);
      final notifier = container.read(reminderControllerProvider.notifier);
      await notifier.setEnabled(true);
      await notifier.setTime(20, 30);

      expect(platform.scheduled.values.every((r) => r.when.hour == 20 && r.when.minute == 30), isTrue);

      await notifier.setEnabled(false);
      expect(platform.scheduled, isEmpty);
      expect(platform.cancelled.toSet(), containsAll(allReminderIds));
    });

    test("today's reminder is dropped once every word is read", () async {
      final container = make(read: {'sql', 'pk', 'idx'});
      await container.read(todayConceptsControllerProvider.future);
      await container.read(reminderControllerProvider.notifier).setEnabled(true);
      expect(platform.scheduled.containsKey(reminderIdFor(DateTime(2026, 11, 23))), isFalse);
      expect(platform.scheduled, hasLength(6));
    });
  });

  testWidgets('ReminderCard shows the time and a preview once switched on', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final platform = FakeReminderPlatform();
    final container = ProviderContainer(overrides: [
      reminderPlatformProvider.overrideWithValue(platform),
      reminderClockProvider.overrideWithValue(() => DateTime(2026, 11, 23, 7, 0)),
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      appUserProvider.overrideWith((ref) => Stream.value(null)),
      todayConceptsControllerProvider.overrideWith(() => FixedToday(TodayConceptsState(
            concepts: [_sql, _pk, _idx],
            readConceptIds: const {},
            isFallback: false,
            userUid: 'u1',
            liveStreak: 2,
          ))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SingleChildScrollView(child: ReminderCard())),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Today: SQL vs NoSQL'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reminder_switch')));
    await tester.pumpAndSettle();

    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('Today: SQL vs NoSQL'), findsOneWidget);
    expect(find.text('SQL vs NoSQL in one line.'), findsOneWidget);
    expect(platform.scheduled, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  test('needsAutostart flags makers with aggressive battery managers', () {
    expect(needsAutostart('Xiaomi'), isTrue);
    expect(needsAutostart(' tecno '), isTrue);
    expect(needsAutostart('Google'), isFalse);
    expect(needsAutostart(''), isFalse);
  });

  testWidgets("Xiaomi without exact alarms shows fix-up rows, and test sends today's reminder", (tester) async {
    SharedPreferences.setMockInitialValues({'reminder_enabled': true});
    final platform = FakeReminderPlatform(exact: false, maker: 'Xiaomi');
    final container = ProviderContainer(overrides: [
      reminderPlatformProvider.overrideWithValue(platform),
      reminderClockProvider.overrideWithValue(() => DateTime(2026, 11, 23, 7, 0)),
      contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
      appUserProvider.overrideWith((ref) => Stream.value(null)),
      todayConceptsControllerProvider.overrideWith(() => FixedToday(TodayConceptsState(
            concepts: [_sql, _pk, _idx],
            readConceptIds: const {},
            isFallback: false,
            userUid: 'u1',
            liveStreak: 2,
          ))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SingleChildScrollView(child: ReminderCard())),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reminder_exact')), findsOneWidget);
    expect(find.textContaining('On Xiaomi phones'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminder_autostart')));
    await tester.pumpAndSettle();
    expect(platform.autostartOpens, 1);

    await tester.tap(find.byKey(const ValueKey('reminder_exact')));
    await tester.pumpAndSettle();
    expect(platform.exactRequests, 1);
    expect(find.byKey(const ValueKey('reminder_exact')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reminder_test')));
    await tester.pumpAndSettle();
    final test = platform.scheduled[testReminderId]!;
    expect(test.message.title, 'Today: SQL vs NoSQL');
    expect(test.when, DateTime(2026, 11, 23, 7, 1));
    expect(find.textContaining('Test reminder set for 7:01 AM'), findsOneWidget);
  });
}
