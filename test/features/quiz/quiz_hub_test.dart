import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/quiz/quiz_hub.dart';

AppUser _user(Map<String, dynamic> log) => AppUser(
      uid: 'u1',
      email: 'a@b.com',
      fieldOfStudy: 'software_engineering',
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
      rawActivityLog: log,
    );

Future<void> _pump(WidgetTester tester, QuizHub hub) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(body: hub)));
  await tester.pump();
}

void main() {
  group('timeUntilQuizOpens', () {
    test('counts down to Saturday midnight on weekdays', () {
      // Wednesday 18 Nov 2026, 10:00.
      final d = timeUntilQuizOpens(DateTime(2026, 11, 18, 10));
      expect(d, const Duration(days: 2, hours: 14));
    });

    test('is null at the weekend', () {
      expect(timeUntilQuizOpens(DateTime(2026, 11, 21, 9)), isNull);
      expect(timeUntilQuizOpens(DateTime(2026, 11, 22, 9)), isNull);
    });
  });

  test('formatCountdown picks the two largest units', () {
    expect(formatCountdown(const Duration(days: 2, hours: 14, minutes: 5)), '2d 14h');
    expect(formatCountdown(const Duration(hours: 5, minutes: 20)), '5h 20m');
    expect(formatCountdown(const Duration(minutes: 12)), '12m');
    expect(formatCountdown(const Duration(seconds: 20)), '1m');
  });

  testWidgets('weekday hub shows the countdown and unlock progress, no start button', (tester) async {
    await _pump(
      tester,
      QuizHub(
        user: _user({
          '2026-11-16': {'concepts_read': ['a', 'b', 'c']},
        }),
        now: () => DateTime(2026, 11, 18, 10),
        status: const QuizStatus(QuizStatusType.notYetOpen),
        primaryLabel: null,
        onPrimary: null,
      ),
    );

    expect(find.text('OPENS SATURDAY'), findsOneWidget);
    expect(find.text('Opens in 2d 14h'), findsOneWidget);
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Your quiz results will appear here.'), findsOneWidget);
  });

  testWidgets('open quiz shows Start Quiz and calls back', (tester) async {
    var started = 0;
    await _pump(
      tester,
      QuizHub(
        user: _user(const {}),
        now: () => DateTime(2026, 11, 21, 10),
        status: const QuizStatus(QuizStatusType.available),
        primaryLabel: 'Start Quiz',
        onPrimary: () => started++,
      ),
    );

    expect(find.text('OPEN NOW'), findsOneWidget);
    expect(find.text("This week's quiz"), findsOneWidget);
    await tester.tap(find.text('Start Quiz'));
    expect(started, 1);
  });

  testWidgets('needing more words says how many', (tester) async {
    await _pump(
      tester,
      QuizHub(
        user: _user(const {}),
        now: () => DateTime(2026, 11, 21, 10),
        status: const QuizStatus(QuizStatusType.needMoreConcepts, 2),
        primaryLabel: null,
        onPrimary: null,
      ),
    );
    expect(find.text('Read 2 more words'), findsOneWidget);
  });

  testWidgets('completed quiz offers results and lists history', (tester) async {
    await _pump(
      tester,
      QuizHub(
        user: _user({
          '2026-11-14': {'quiz_type': 'weekly', 'quiz_score': 9, 'quiz_total': 10, 'quiz_tier': 'excellent'},
        }),
        now: () => DateTime(2026, 11, 21, 10),
        status: const QuizStatus(QuizStatusType.completed),
        primaryLabel: 'View Results',
        onPrimary: () {},
      ),
    );
    expect(find.text('Quiz complete'), findsOneWidget);
    expect(find.text('View Results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
