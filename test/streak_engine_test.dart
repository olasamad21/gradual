import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/services/streak_engine.dart';

void main() {
  group('StreakEngine Core', () {
    test('empty log yields 0 streak', () {
      final log = <String, dynamic>{};
      final today = DateTime(2026, 10, 5);
      expect(StreakEngine.currentStreak(log, today), 0);
      expect(StreakEngine.longestStreak(log), 0);
    });

    test('today unlogged + yesterday logged keeps streak alive', () {
      final log = {
        '2026-10-04': {
          'concepts_read': ['c1']
        }
      };
      final today = DateTime(2026, 10, 5);
      expect(StreakEngine.currentStreak(log, today), 1);
    });

    test('one-day gap resets streak', () {
      final log = {
        '2026-10-03': {
          'concepts_read': ['c1']
        }
      };
      final today = DateTime(2026, 10, 5); // 04 is missing
      expect(StreakEngine.currentStreak(log, today), 0);
    });

    test('quiz-only day does not count towards streak', () {
      final log = {
        '2026-10-04': {
          'quiz_score': 5
        }
      };
      final today = DateTime(2026, 10, 5);
      expect(StreakEngine.currentStreak(log, today), 0);
    });

    test('day repeating only already-read concepts does not count', () {
      final log = {
        '2026-10-03': {
          'concepts_read': ['c1', 'c2']
        },
        '2026-10-04': {
          'concepts_read': ['c1'] // duplicate from yesterday
        }
      };
      final today = DateTime(2026, 10, 5);
      expect(StreakEngine.currentStreak(log, today), 0); // 04 didn't count, so 05 is broken
      expect(StreakEngine.longestStreak(log), 1);
    });

    test('day with 1 new + 2 old concepts counts', () {
      final log = {
        '2026-10-03': {
          'concepts_read': ['c1', 'c2']
        },
        '2026-10-04': {
          'concepts_read': ['c1', 'c2', 'c3'] // c3 is new
        }
      };
      final today = DateTime(2026, 10, 5);
      expect(StreakEngine.currentStreak(log, today), 2);
    });

    test('month boundary calculation', () {
      final log = {
        '2026-09-30': {'concepts_read': ['c1']},
        '2026-10-01': {'concepts_read': ['c2']},
      };
      final today = DateTime(2026, 10, 1);
      expect(StreakEngine.currentStreak(log, today), 2);
    });

    test('year boundary calculation', () {
      final log = {
        '2025-12-31': {'concepts_read': ['c1']},
        '2026-01-01': {'concepts_read': ['c2']},
      };
      final today = DateTime(2026, 1, 1);
      expect(StreakEngine.currentStreak(log, today), 2);
    });

    test('DST dates (Spring Forward: 2026-03-08)', () {
      final log = {
        '2026-03-07': {'concepts_read': ['c1']},
        '2026-03-08': {'concepts_read': ['c2']},
      };
      final today = DateTime(2026, 3, 9);
      expect(StreakEngine.currentStreak(log, today), 2);
    });

    test('DST dates (Fall Back: 2026-11-01)', () {
      final log = {
        '2026-10-31': {'concepts_read': ['c1']},
        '2026-11-01': {'concepts_read': ['c2']},
      };
      final today = DateTime(2026, 11, 2);
      expect(StreakEngine.currentStreak(log, today), 2);
    });

    test('perfect day with set size 3', () {
      final log = {
        '2026-10-05': {'concepts_read': ['c1', 'c2', 'c3']}, // counted & perfect
        '2026-10-06': {'concepts_read': ['c4', 'c5']},       // counted, not perfect
        '2026-10-07': {'concepts_read': ['c1', 'c2', 'c3']}  // not counted (all duplicate), not perfect
      };
      expect(StreakEngine.isPerfectDay(log, '2026-10-05', 3), isTrue);
      expect(StreakEngine.isPerfectDay(log, '2026-10-06', 3), isFalse);
      expect(StreakEngine.isPerfectDay(log, '2026-10-07', 3), isFalse);
    });

    test('malformed entries are handled safely', () {
      final log = {
        '2026-10-05': null,
        '2026-10-06': 'string instead of map',
        '2026-10-07': {'concepts_read': 'not a list'},
        '2026-10-08': {'concepts_read': [123, true, 'c1']} // mixed types
      };
      // only c1 counts
      final counted = StreakEngine.countedDays(log);
      expect(counted, {'2026-10-08'});
    });
  });

  group('StreakEngine Weekly Math & Quiz', () {
    test('quizDateIdInWeek behavior', () {
      final today = DateTime(2026, 10, 11); // Sunday
      // No quiz -> null
      expect(StreakEngine.quizDateIdInWeek({}, today), null);

      // Quiz Saturday -> Saturday's id
      final logSat = {'2026-10-10': {'quiz_score': 5}};
      expect(StreakEngine.quizDateIdInWeek(logSat, today), '2026-10-10');

      // Quiz previous week -> null
      final logPrev = {'2026-10-04': {'quiz_score': 5}}; // previous Sunday
      expect(StreakEngine.quizDateIdInWeek(logPrev, today), null);

      // Malformed entries don't throw
      final logMalformed = {'2026-10-10': 'not a map', '2026-10-09': {'quiz_score': 10}};
      expect(StreakEngine.quizDateIdInWeek(logMalformed, today), '2026-10-09');
    });

    test('weekStartId for each weekday incl. Sunday', () {
      // 2026-10-05 is a Monday
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 5)), '2026-10-05');
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 6)), '2026-10-05');
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 7)), '2026-10-05');
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 8)), '2026-10-05');
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 9)), '2026-10-05');
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 10)), '2026-10-05'); // Saturday
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 11)), '2026-10-05'); // Sunday
      // Next Monday
      expect(StreakEngine.weekStartId(DateTime(2026, 10, 12)), '2026-10-12');
    });

    test('week boundaries: Sunday belongs to the week that started previous Monday', () {
      final log = {
        '2026-10-11': {'concepts_read': ['c1']}, // Sunday
        '2026-10-12': {'concepts_read': ['c2']}  // Monday
      };
      final sunday = DateTime(2026, 10, 11);
      final monday = DateTime(2026, 10, 12);
      
      final readSundayWeek = StreakEngine.conceptsReadInWeek(log, sunday);
      expect(readSundayWeek, {'c1'}); // c2 is next week
      
      final readMondayWeek = StreakEngine.conceptsReadInWeek(log, monday);
      expect(readMondayWeek, {'c2'});
    });

    test('quizStatus for every state', () {
      // 2026-10-07 is Wednesday (window not open)
      final wednesday = DateTime(2026, 10, 7);
      expect(StreakEngine.quizStatus({}, wednesday).type, QuizStatusType.notYetOpen);

      // 2026-10-10 is Saturday (window open)
      final saturday = DateTime(2026, 10, 10);
      final log1 = {
        '2026-10-05': {'concepts_read': ['c1', 'c2']},
        '2026-10-06': {'concepts_read': ['c3']}
      }; // 3 concepts read this week
      
      final status1 = StreakEngine.quizStatus(log1, saturday);
      expect(status1.type, QuizStatusType.needMoreConcepts);
      expect(status1.conceptsNeeded, 2);

      final log2 = {
        '2026-10-05': {'concepts_read': ['c1', 'c2']},
        '2026-10-06': {'concepts_read': ['c3', 'c4']},
        '2026-10-07': {'concepts_read': ['c5']}
      }; // 5 concepts read
      expect(StreakEngine.quizStatus(log2, saturday).type, QuizStatusType.available);

      final log3 = {
        '2026-10-05': {'concepts_read': ['c1', 'c2', 'c3', 'c4', 'c5']},
        '2026-10-10': {'quiz_score': 10}
      }; // taken on Saturday
      expect(StreakEngine.quizStatus(log3, saturday).type, QuizStatusType.completed);
    });

    test('quiz taken Saturday blocks Sunday', () {
      final saturday = DateTime(2026, 10, 10);
      final sunday = DateTime(2026, 10, 11);
      final log = {
        '2026-10-05': {'concepts_read': ['c1', 'c2', 'c3', 'c4', 'c5']},
        '2026-10-10': {'quiz_score': 10}
      };
      
      expect(StreakEngine.quizStatus(log, saturday).type, QuizStatusType.completed);
      expect(StreakEngine.quizStatus(log, sunday).type, QuizStatusType.completed);
    });
  });
}
