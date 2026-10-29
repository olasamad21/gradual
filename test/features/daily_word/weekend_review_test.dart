import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'package:gradual/features/daily_word/concept_flip_card.dart';
import 'package:gradual/features/daily_word/concept_providers.dart';
import 'package:gradual/features/daily_word/concept_section_style.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';
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

  group('ConceptFlipCard weekend review tests', () {
    testWidgets('renders WEEKEND REVIEW label on both faces when isWeekendReview is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ConceptFlipCard(
                  concept: testConcept,
                  index: 0,
                  isRead: false,
                  isLastWord: false,
                  totalCount: 15,
                  isWeekendReview: true,
                  onMarkRead: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('WEEKEND REVIEW'), findsOneWidget);
    });

    testWidgets('shows "All caught up for this week!" when last word is read in weekend review', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ConceptFlipCard(
                  concept: testConcept,
                  index: 14,
                  isRead: true,
                  isLastWord: true,
                  totalCount: 15,
                  isWeekendReview: true,
                  onMarkRead: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap card to flip to back face where completion message is shown
      await tester.tap(find.text('Polymorphism'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('All caught up for this week!'), findsOneWidget);
      expect(find.text('All done for today'), findsNothing);
    });

    testWidgets('shows "All done for today" when last word is read in weekday mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ConceptFlipCard(
                  concept: testConcept,
                  index: 2,
                  isRead: true,
                  isLastWord: true,
                  totalCount: 3,
                  isWeekendReview: false,
                  onMarkRead: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap card to flip to back face where completion message is shown
      await tester.tap(find.text('Polymorphism'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('All done for today'), findsOneWidget);
      expect(find.text('All caught up for this week!'), findsNothing);
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
