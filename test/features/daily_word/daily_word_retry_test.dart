import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradual/core/errors/firestore_errors.dart';
import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/repositories/content_repository.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/concept_providers.dart';
import 'package:gradual/features/daily_word/daily_word_screen.dart';
import 'package:gradual/features/daily_word/today_concepts_controller.dart';
import 'package:gradual/features/streak/streak_providers.dart';

const sampleConcept = Concept(
  id: 'c1',
  term: 'Recursion',
  definition: 'A function calling itself.',
  analogy: 'Russian nesting dolls.',
  realWorldExample: 'Directory traversal.',
  confusedWith: 'Iteration',
  category: 'Algorithms',
  level: 'beginner',
  related: [],
  quiz: ConceptQuiz(
    question: 'What is recursion?',
    options: ['Self-call', 'Loop'],
    answerIndex: 0,
    explanation: 'Calls itself.',
  ),
);

void main() {
  final testUser = AppUser(
    uid: 'user_1',
    email: 'test@example.com',
    fieldOfStudy: 'software_engineering',
    currentStreak: 0,
    lastActivityDate: null,
    activityLog: {},
    rawActivityLog: {},
  );

  testWidgets('provider test: retryLoadConcepts clears cached failure and reaches data state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bool failConcepts = true;

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(testUser)),
        statsResetProvider.overrideWith((ref) async {}),
        todaysConceptsProvider.overrideWith((ref) async {
          if (failConcepts) {
            throw FirestoreErrors.toAppException(Exception('network error'));
          }
          return const TodaysConceptsResult(
            concepts: [sampleConcept],
            isFallback: false,
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    // Read the provider (starts loading)
    container.read(todayConceptsControllerProvider);

    // Pump fake async time until controller finishes loading and reaches error state
    while (container.read(todayConceptsControllerProvider).isLoading) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(container.read(todayConceptsControllerProvider).hasError, isTrue);

    // Set repository to succeed on next call
    failConcepts = false;

    // Call the retry function
    retryLoadConcepts(container);

    // Pump fake async time until controller finishes loading and reaches data state
    while (container.read(todayConceptsControllerProvider).isLoading) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final state = container.read(todayConceptsControllerProvider).requireValue;
    expect(state.concepts.length, 1);
    expect(state.concepts.first.id, 'c1');
    expect(container.read(todayConceptsControllerProvider).hasError, isFalse);
  });

  testWidgets('widget test: error state shows Retry button with finite width > 0, tap shows spinner and disables button', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        appUserProvider.overrideWith((ref) => Stream.value(testUser)),
        statsResetProvider.overrideWith((ref) async {}),
        todaysConceptsProvider.overrideWith((ref) async {
          throw FirestoreErrors.toAppException(Exception('offline failure'));
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DailyWordScreen(),
        ),
      ),
    );

    // Pump until the controller finishes loading and reaches error state
    while (container.read(todayConceptsControllerProvider).isLoading) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();

    final retryFinder = find.widgetWithText(TextButton, 'Retry');
    expect(retryFinder, findsOneWidget);

    final size = tester.getSize(retryFinder);
    expect(size.width.isFinite, isTrue);
    expect(size.height.isFinite, isTrue);
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));

    // Tap Retry
    await tester.tap(retryFinder);
    await tester.pump();

    // Progress indicator is visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Button is disabled
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.enabled, isFalse);

    // Advance past the 10-second retry timer so no pending timers remain
    await tester.pump(const Duration(seconds: 11));

    expect(tester.takeException(), isNull);
  });
}
