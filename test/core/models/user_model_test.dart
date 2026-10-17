import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'package:gradual/features/profile/profile_quiz_stats.dart';

void main() {
  group('AppUser.fromJson tests', () {
    test('1. activity_log populates rawActivityLog correctly', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b']
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.rawActivityLog, {
        '2026-10-03': {
          'concepts_read': ['a', 'b']
        }
      });
    });

    test('2. user.streakAt returns 1 for the populated log', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b']
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.streakAt(DateTime(2026, 10, 3)), 1);
    });

    test('3. StreakEngine.conceptsReadInWeek returns correctly', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b']
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      final concepts = StreakEngine.conceptsReadInWeek(user.rawActivityLog, DateTime(2026, 10, 4));
      
      expect(concepts, {'a', 'b'});
    });

    test('4. json with no activity_log gives empty rawActivityLog and does not throw', () {
      final json = <String, dynamic>{
        'email': 'test@test.com',
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.rawActivityLog, isEmpty);
    });

    test('5. log entry with quiz and concepts keeps both in rawActivityLog', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b'],
            'quiz_score': 8,
            'quiz_total': 10,
            'quiz_tier': 'bronze'
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.rawActivityLog, {
        '2026-10-03': {
          'concepts_read': ['a', 'b'],
          'quiz_score': 8,
          'quiz_total': 10,
          'quiz_tier': 'bronze'
        }
      });
    });

    test('6. AppUser.fromJson with a new-style quiz entry gives 1 quiz done, the right score and total, and the right percentage', () {
      final json = {
        'activity_log': {
          '2026-10-10': {
            'quiz_score': 8,
            'quiz_total': 10,
            'quiz_tier': 'good',
          }
        }
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 1);
      final entry = user.activityLog['2026-10-10']!;
      expect(entry.isWeeklyQuiz, isTrue);
      expect(entry.score, 8);
      expect(entry.totalQuestions, 10);
      expect(entry.quizScore, 8);
      expect(entry.quizTotal, 10);
      expect(allTimeCorrectPercent(user), '80%');
    });

    test('7. a legacy weekly entry still counts with its score', () {
      final json = {
        'activity_log': {
          '2026-09-26': {
            'quiz_type': 'weekly',
            'score': 7,
            'total_questions': 10,
            'tier': 'good',
          }
        }
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 1);
      final entry = user.activityLog['2026-09-26']!;
      expect(entry.isWeeklyQuiz, isTrue);
      expect(entry.score, 7);
      expect(entry.totalQuestions, 10);
      expect(allTimeCorrectPercent(user), '70%');
    });

    test('8. an entry with only concepts_read counts as no quiz and the rate shows "--" when there are no quizzes', () {
      final json = {
        'activity_log': {
          '2026-10-05': {
            'concepts_read': ['a', 'b', 'c'],
          }
        }
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 0);
      expect(allTimeCorrectPercent(user), '--');
    });

    test('9. two quizzes on different dates sum correctly and appear newest first', () {
      final json = {
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
        }
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 2);
      final stats = quizStatsTotals(user);
      expect(stats.totalCorrect, 14);
      expect(stats.totalQuestions, 20);
      expect(allTimeCorrectPercent(user), '70%');

      final history = sortedQuizHistoryEntries(user);
      expect(history.length, 2);
      expect(history[0].key, '2026-10-10');
      expect(history[1].key, '2026-10-03');
    });

    test('10. malformed values (strings, nulls, negative numbers) do not throw and are not counted', () {
      final json = {
        'activity_log': {
          '2026-10-01': {
            'quiz_score': 'eight',
            'quiz_total': 10,
          },
          '2026-10-02': {
            'quiz_score': null,
            'quiz_total': null,
          },
          '2026-10-03': {
            'quiz_score': -3,
            'quiz_total': 10,
          },
          '2026-10-04': {
            'quiz_score': 3,
            'quiz_total': -10,
          },
          '2026-10-05': {
            'quiz_type': 'weekly',
            'score': -1,
            'total_questions': 10,
          },
        }
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 0);
      expect(allTimeCorrectPercent(user), '--');
    });

    test('11. a quiz and concepts_read on the same day keeps both (the concepts still appear in rawActivityLog)', () {
      final json = {
        'activity_log': {
          '2026-10-10': {
            'concepts_read': ['c1', 'c2'],
            'quiz_score': 9,
            'quiz_total': 10,
            'quiz_tier': 'excellent',
          }
        }
      };

      final user = AppUser.fromJson('u1', json);

      expect(totalQuizzesDoneCount(user), 1);
      expect(allTimeCorrectPercent(user), '90%');
      expect(user.rawActivityLog['2026-10-10']['concepts_read'], ['c1', 'c2']);
      expect(user.activityLog['2026-10-10']?.conceptsRead, ['c1', 'c2']);
      expect(user.activityLog['2026-10-10']?.isWeeklyQuiz, isTrue);
    });
  });
}
