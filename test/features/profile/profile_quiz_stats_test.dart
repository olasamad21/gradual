import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/features/profile/profile_quiz_stats.dart';

void main() {
  group('profile_quiz_stats unit tests', () {
    test('1. AppUser.fromJson with a new-style quiz entry gives 1 quiz done, the right score and total, and the right percentage', () {
      final json = {
        'email': 'student@example.com',
        'activity_log': {
          '2026-10-10': {
            'quiz_score': 8,
            'quiz_total': 10,
            'quiz_tier': 'good',
          },
        },
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 1);
      expect(totalQuizzesDone(user), '1');

      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 8);
      expect(stats.totalQuestions, 10);

      expect(allTimeCorrectPercent(user), '80%');

      final history = sortedQuizHistoryEntries(user);
      expect(history.length, 1);
      expect(history.first.key, '2026-10-10');
      expect(history.first.value.score, 8);
      expect(history.first.value.totalQuestions, 10);
      expect(history.first.value.tier, WeeklyScoreTier.good);
    });

    test('2. a legacy weekly entry still counts with its score', () {
      final json = {
        'email': 'student@example.com',
        'activity_log': {
          '2026-09-26': {
            'quiz_type': 'weekly',
            'score': 7,
            'total_questions': 10,
            'tier': 'good',
          },
        },
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 1);
      expect(totalQuizzesDone(user), '1');

      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 7);
      expect(stats.totalQuestions, 10);

      expect(allTimeCorrectPercent(user), '70%');

      final history = sortedQuizHistoryEntries(user);
      expect(history.length, 1);
      expect(history.first.key, '2026-09-26');
      expect(history.first.value.score, 7);
      expect(history.first.value.totalQuestions, 10);
    });

    test('3. an entry with only concepts_read counts as no quiz and the rate shows "--" when there are no quizzes', () {
      final json = {
        'email': 'student@example.com',
        'activity_log': {
          '2026-10-05': {
            'concepts_read': ['c1', 'c2', 'c3'],
          },
        },
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 0);
      expect(totalQuizzesDone(user), '0');

      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 0);
      expect(stats.totalQuestions, 0);

      expect(allTimeCorrectPercent(user), '--');
      expect(sortedQuizHistoryEntries(user), isEmpty);
    });

    test('4. two quizzes on different dates sum correctly and appear newest first', () {
      final json = {
        'email': 'student@example.com',
        'activity_log': {
          '2026-10-03': {
            'quiz_score': 8,
            'quiz_total': 10,
            'quiz_tier': 'good',
          },
          '2026-10-10': {
            'quiz_score': 6,
            'quiz_total': 10,
            'quiz_tier': 'good',
          },
        },
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 2);
      expect(totalQuizzesDone(user), '2');

      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 14);
      expect(stats.totalQuestions, 20);

      expect(allTimeCorrectPercent(user), '70%');

      final history = sortedQuizHistoryEntries(user);
      expect(history.length, 2);
      expect(history[0].key, '2026-10-10');
      expect(history[0].value.score, 6);
      expect(history[1].key, '2026-10-03');
      expect(history[1].value.score, 8);
    });

    test('5. malformed values (strings, nulls, negative numbers) do not throw and are not counted', () {
      final json = {
        'email': 'student@example.com',
        'activity_log': {
          '2026-10-01': {
            'quiz_score': 'not_a_number',
            'quiz_total': 10,
          },
          '2026-10-02': {
            'quiz_score': null,
            'quiz_total': 10,
          },
          '2026-10-03': {
            'quiz_score': -5,
            'quiz_total': 10,
          },
          '2026-10-04': {
            'quiz_score': 5,
            'quiz_total': -10,
          },
          '2026-10-05': {
            'quiz_type': 'weekly',
            'score': -1,
            'total_questions': 10,
          },
        },
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 0);
      expect(totalQuizzesDone(user), '0');

      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 0);
      expect(stats.totalQuestions, 0);

      expect(allTimeCorrectPercent(user), '--');
      expect(sortedQuizHistoryEntries(user), isEmpty);
    });

    test('6. a quiz and concepts_read on the same day keeps both (the concepts still appear in rawActivityLog)', () {
      final json = {
        'email': 'student@example.com',
        'activity_log': {
          '2026-10-10': {
            'concepts_read': ['c1', 'c2'],
            'quiz_score': 9,
            'quiz_total': 10,
            'quiz_tier': 'excellent',
          },
        },
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 1);
      expect(totalQuizzesDone(user), '1');

      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 9);
      expect(stats.totalQuestions, 10);

      expect(allTimeCorrectPercent(user), '90%');

      expect(user.rawActivityLog['2026-10-10']['concepts_read'], ['c1', 'c2']);
      expect(user.activityLog['2026-10-10']?.conceptsRead, ['c1', 'c2']);
      expect(user.activityLog['2026-10-10']?.isWeeklyQuiz, isTrue);
      expect(user.activityLog['2026-10-10']?.score, 9);
      expect(user.activityLog['2026-10-10']?.totalQuestions, 10);
      expect(user.activityLog['2026-10-10']?.tier, WeeklyScoreTier.excellent);
    });
  });
}
