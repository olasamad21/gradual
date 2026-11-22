import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'package:gradual/features/daily_word/day_complete_card.dart';
import 'package:gradual/features/daily_word/concept_providers.dart';
import 'package:gradual/features/daily_word/concept_section_style.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';
import 'package:gradual/features/daily_word/today_header.dart';
import 'package:gradual/features/streak/streak_providers.dart';

void main() {
  final testConcept = Concept(
    id: 'c1',
    term: 'Polymorphism',
    category: 'software-engineering',
    definition: 'Ability of different types to respond to the same interface.',
    level: 'beginner',
    analogy: 'A universal remote control.',
    realWorldExample: 'A shape class with draw() method.',
    confusedWith: 'Inheritance',
    related: const ['Encapsulation'],
    quiz: const ConceptQuiz(question: 'Q', options: ['A', 'B'], answerIndex: 0, explanation: ''),
  );

  group('WordIndexPill tests', () {
    testWidgets('renders WORDS OF THE DAY by default with total', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: WordIndexPill(index: 0, isRead: false, total: 3),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('WORDS OF THE DAY'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('renders custom label WEEKEND REVIEW with total', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: WordIndexPill(
              index: 4,
              isRead: false,
              total: 15,
              label: 'WEEKEND REVIEW',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('WEEKEND REVIEW'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });

  group('Today screen weekend review', () {
    Widget host(Widget child) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: SizedBox(width: 400, height: 640, child: child)),
        );

    testWidgets('header labels a weekend review and counts reviewed words', (tester) async {
      await tester.pumpWidget(host(TodayHeader(
        greeting: 'Good morning',
        firstName: 'Ada',
        streak: 4,
        readCount: 2,
        total: 15,
        rawActivityLog: const {},
        today: DateTime(2026, 11, 21),
        isWeekendReview: true,
      )));
      await tester.pump();

      expect(find.text('2 of 15 reviewed'), findsOneWidget);
      expect(find.text('Weekend review · words from this week'), findsOneWidget);
    });

    testWidgets('complete card says "All caught up for this week!" on a weekend', (tester) async {
      await tester.pumpWidget(host(DayCompleteCard(
        concepts: [testConcept],
        streak: 3,
        isWeekendReview: true,
        onOpenWord: (_) {},
      )));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('All caught up for this week!'), findsOneWidget);
      expect(find.text('All done for today'), findsNothing);
      expect(find.text('New words on Monday'), findsOneWidget);
    });

    testWidgets('complete card says "All done for today" on a weekday', (tester) async {
      await tester.pumpWidget(host(DayCompleteCard(
        concepts: [testConcept],
        streak: 3,
        isWeekendReview: false,
        onOpenWord: (_) {},
      )));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('All done for today'), findsOneWidget);
      expect(find.text('All caught up for this week!'), findsNothing);
      expect(find.text('New words tomorrow'), findsOneWidget);
    });
  });

  AppUser createTestUser({Map<String, dynamic> rawActivityLog = const {}}) {
    return AppUser(
      uid: 'u1',
      email: 'test@example.com',
      fieldOfStudy: 'software_engineering',
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
      rawActivityLog: rawActivityLog,
    );
  }

  group('TodayConceptsController weekend review read state tests', () {
    test('in weekend review, concepts read earlier in the week are marked read', () async {
      final thisMonday = StreakEngine.weekStartId(DateTime.now());
      final container = ProviderContainer(
        overrides: [
          statsResetProvider.overrideWith((ref) => Future.value(null)),
          appUserProvider.overrideWith((ref) {
            return Stream.value(
              createTestUser(
                rawActivityLog: {
                  // Concept c1 was read earlier in the current week (on Monday)
                  thisMonday: {
                    'concepts_read': ['c1'],
                  },
                },
              ),
            );
          }),
          todaysConceptsProvider.overrideWith((ref) async {
            return TodaysConceptsResult(
              concepts: [testConcept],
              isWeekendReview: true,
              isFallback: false,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(appUserProvider, (_, _) {});
      container.listen(todayConceptsControllerProvider, (_, _) {});

      while (container.read(todayConceptsControllerProvider).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final state = container.read(todayConceptsControllerProvider).requireValue;
      expect(state.isWeekendReview, isTrue);
      expect(state.concepts.length, 1);
      // c1 was read during this week, so readConceptIds should contain c1!
      expect(state.readConceptIds.contains('c1'), isTrue);
    });

    test('in weekday mode, only concepts read today are marked read', () async {
      const pastDate = '2020-01-01';
      final container = ProviderContainer(
        overrides: [
          statsResetProvider.overrideWith((ref) => Future.value(null)),
          appUserProvider.overrideWith((ref) {
            return Stream.value(
              createTestUser(
                rawActivityLog: {
                  // Concept c1 was read on an earlier date, not today
                  pastDate: {
                    'concepts_read': ['c1'],
                  },
                },
              ),
            );
          }),
          todaysConceptsProvider.overrideWith((ref) async {
            return TodaysConceptsResult(
              concepts: [testConcept],
              isWeekendReview: false,
              isFallback: false,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(appUserProvider, (_, _) {});
      container.listen(todayConceptsControllerProvider, (_, _) {});

      while (container.read(todayConceptsControllerProvider).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final state = container.read(todayConceptsControllerProvider).requireValue;
      expect(state.isWeekendReview, isFalse);
      expect(state.concepts.length, 1);
      // In weekday mode, c1 read on 2020-01-01 is not today's read
      expect(state.readConceptIds.contains('c1'), isFalse);
    });
  });
}
