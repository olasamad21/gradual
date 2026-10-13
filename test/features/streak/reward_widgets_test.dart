import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/daily_word_screen.dart';
import 'package:gradual/features/streak/day_reward_overlay.dart';
import 'package:gradual/features/streak/quiz_result_box.dart';
import 'package:gradual/features/streak/reward_burst.dart';
import 'package:gradual/shared/widgets/streak_box.dart';

void main() {
  group('DayRewardOverlay tests', () {
    testWidgets('DayRewardOverlay shows the title and caption for perfect and for counted', (tester) async {
      // Perfect day
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: DayRewardOverlay(
              reward: DayReward.perfect,
              streakCount: 3,
            ),
          ),
        ),
      );
      expect(find.text('Perfect day!'), findsOneWidget);
      expect(find.text('All 3 concepts done'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Counted day
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: DayRewardOverlay(
              reward: DayReward.counted,
              streakCount: 5,
            ),
          ),
        ),
      );
      expect(find.text('Day counted'), findsOneWidget);
      expect(find.text('5 day streak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it closes by itself after pump(Duration(seconds: 4))', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DayRewardOverlay.show(
                    ctx,
                    reward: DayReward.counted,
                    streakCount: 2,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Day counted'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Day counted'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping it closes it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DayRewardOverlay.show(
                    ctx,
                    reward: DayReward.counted,
                    streakCount: 2,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Day counted'), findsOneWidget);

      await tester.tap(find.byType(DayRewardOverlay));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Day counted'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with disableAnimations true no exception and the box is at full size immediately', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: DayRewardOverlay(
                reward: DayReward.counted,
                streakCount: 1,
              ),
            ),
          ),
        ),
      );

      final boxFinder = find.byType(StreakBox);
      expect(boxFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(boxFinder);
      expect(renderBox.size.width, 64.0);
      expect(renderBox.size.height, 64.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 throws nothing on DayRewardOverlay', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: DayRewardOverlay(
                reward: DayReward.perfect,
                streakCount: 3,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('RewardBurst tests', () {
    testWidgets('RewardBurst draws without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: RewardBurst(
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CustomPaint is absent or empty when animations are disabled', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: RewardBurst(
                child: SizedBox(width: 50, height: 50),
              ),
            ),
          ),
        ),
      );
      expect(
        find.descendant(of: find.byType(RewardBurst), matching: find.byType(CustomPaint)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('QuizResultBox tests', () {
    testWidgets('QuizResultBox shows each caption', (tester) async {
      const tiersAndCaptions = {
        'excellent': 'Excellent',
        'good': 'Good',
        'fair': 'Fair',
        'failed': 'Keep practicing',
      };

      for (final entry in tiersAndCaptions.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: QuizResultBox(tier: entry.key),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the failed box shows no ScaleTransition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: QuizResultBox(tier: 'failed'),
          ),
        ),
      );
      expect(
        find.descendant(of: find.byType(QuizResultBox), matching: find.byType(ScaleTransition)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 throws nothing on QuizResultBox', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: QuizResultBox(tier: 'excellent'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Screen-level reward decision logic tests (shouldTriggerReward)', () {
    test('goes from 0 to 1 new concept read today: trigger is true', () {
      final trigger = shouldTriggerReward(
        previousCount: 0,
        newCount: 1,
        reward: DayReward.counted,
        isFallback: false,
        alreadyShown: false,
      );
      expect(trigger, isTrue);
    });

    test('first emitted value alone (previousCount == newCount == 0): trigger is false', () {
      final trigger = shouldTriggerReward(
        previousCount: 0,
        newCount: 0,
        reward: DayReward.counted,
        isFallback: false,
        alreadyShown: false,
      );
      expect(trigger, isFalse);
    });

    test('second update with the same count (1 -> 1): trigger is false', () {
      final trigger = shouldTriggerReward(
        previousCount: 1,
        newCount: 1,
        reward: DayReward.counted,
        isFallback: false,
        alreadyShown: false,
      );
      expect(trigger, isFalse);
    });

    test('fallback day shows nothing even when count increases', () {
      final trigger = shouldTriggerReward(
        previousCount: 0,
        newCount: 1,
        reward: DayReward.counted,
        isFallback: true,
        alreadyShown: false,
      );
      expect(trigger, isFalse);
    });

    test('already shown returns false', () {
      final trigger = shouldTriggerReward(
        previousCount: 0,
        newCount: 1,
        reward: DayReward.counted,
        isFallback: false,
        alreadyShown: true,
      );
      expect(trigger, isFalse);
    });

    test('DayReward.none returns false', () {
      final trigger = shouldTriggerReward(
        previousCount: 0,
        newCount: 1,
        reward: DayReward.none,
        isFallback: false,
        alreadyShown: false,
      );
      expect(trigger, isFalse);
    });

    test('perfect day transition (2 -> 3) returns true when not already shown', () {
      final trigger = shouldTriggerReward(
        previousCount: 2,
        newCount: 3,
        reward: DayReward.perfect,
        isFallback: false,
        alreadyShown: false,
      );
      expect(trigger, isTrue);
    });
  });
}
