import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/config/app_rules.dart';
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
    test('quizDateIdInWeek - no quiz', () {
      final today = DateTime(2026, 10, 11); // Sunday
      expect(StreakEngine.quizDateIdInWeek({}, today), null);
    });

    test('quizDateIdInWeek - Saturday seen from Sunday', () {
      final today = DateTime(2026, 10, 11);
      final logSat = {'2026-10-10': {'quiz_score': 5}};
      expect(StreakEngine.quizDateIdInWeek(logSat, today), '2026-10-10');
    });

    test('quizDateIdInWeek - previous week', () {
      final today = DateTime(2026, 10, 11);
      final logPrev = {'2026-10-04': {'quiz_score': 5}}; // previous Sunday
      expect(StreakEngine.quizDateIdInWeek(logPrev, today), null);
    });

    test('quizDateIdInWeek - malformed', () {
      final today = DateTime(2026, 10, 11);
      // quiz_score null does not count
      final logMalformed = {'2026-10-10': 'not a map', '2026-10-09': {'quiz_score': null}, '2026-10-08': {'quiz_score': 10}};
      expect(StreakEngine.quizDateIdInWeek(logMalformed, today), '2026-10-08');
    });

    test('quizTakenThisWeek is consistent with quizDateIdInWeek', () {
      final today = DateTime(2026, 10, 11);
      final logs = <Map<String, dynamic>>[
        {},
        {'2026-10-10': {'quiz_score': 5}},
        {'2026-10-04': {'quiz_score': 5}},
        {'2026-10-10': 'not a map', '2026-10-09': {'quiz_score': null}, '2026-10-08': {'quiz_score': 10}}
      ];
      for (final log in logs) {
        expect(
          StreakEngine.quizTakenThisWeek(log, today),
          StreakEngine.quizDateIdInWeek(log, today) != null,
        );
      }
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
      final N = AppRules.quizMinConceptsThisWeek;
      final monday = DateTime(2026, 10, 5);
      final weekDays = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));

      DateTime? openDate;
      DateTime? closedDate;
      for (final d in weekDays) {
        if (AppRules.quizWindowWeekdays.contains(d.weekday)) {
          openDate ??= d;
        } else {
          closedDate ??= d;
        }
      }

      if (closedDate != null) {
        expect(StreakEngine.quizStatus({}, closedDate).type, QuizStatusType.notYetOpen);
      } else {
        // ignore: avoid_print
        print('Skipping notYetOpen assertion: no closed weekday found in AppRules.quizWindowWeekdays');
      }

      expect(openDate, isNotNull);

      if (N >= 1) {
        final conceptsNMinus1 = List.generate(N - 1, (i) => 'concept_$i');
        final logNeedMore = {
          '2026-10-05': {'concepts_read': conceptsNMinus1},
        };
        final statusNeedMore = StreakEngine.quizStatus(logNeedMore, openDate!);
        expect(statusNeedMore.type, QuizStatusType.needMoreConcepts);
        expect(statusNeedMore.conceptsNeeded, 1);
      }

      final conceptsN = List.generate(N, (i) => 'concept_$i');
      final logAvailable = {
        '2026-10-05': {'concepts_read': conceptsN},
      };
      expect(StreakEngine.quizStatus(logAvailable, openDate!).type, QuizStatusType.available);

      final openDateStr = '${openDate.year}-${openDate.month.toString().padLeft(2, '0')}-${openDate.day.toString().padLeft(2, '0')}';
      final logCompleted = <String, dynamic>{
        '2026-10-05': {'concepts_read': conceptsN},
      };
      final existing = (logCompleted[openDateStr] as Map<String, dynamic>?) ?? {};
      logCompleted[openDateStr] = {
        ...existing,
        'quiz_score': 10,
      };
      expect(StreakEngine.quizStatus(logCompleted, openDate).type, QuizStatusType.completed);

      // A quiz score from the PREVIOUS week does not count as completed.
      final logPrevWeekQuiz = {
        '2026-10-04': {'quiz_score': 10},
        '2026-10-05': {'concepts_read': conceptsN},
      };
      expect(StreakEngine.quizStatus(logPrevWeekQuiz, openDate).type, QuizStatusType.available);
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

  group('HeatmapCell', () {
    test('none: empty log and a day with no entry', () {
      expect(StreakEngine.heatmapCell({}, '2026-10-10', 3), HeatmapCell.none);
      expect(StreakEngine.heatmapCell({'2026-10-09': {}}, '2026-10-10', 3), HeatmapCell.none);
    });

    test('partial: a day with 1 concept read', () {
      final log = {
        '2026-10-10': {'concepts_read': ['c1']}
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.partial);
    });

    test('perfect: 3 concepts read (setSize 3), and NOT perfect with 2', () {
      final log = {
        '2026-10-10': {'concepts_read': ['c1', 'c2']},
        '2026-10-11': {'concepts_read': ['c1', 'c2', 'c3']}
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.partial);
      expect(StreakEngine.heatmapCell(log, '2026-10-11', 3), HeatmapCell.perfect);
    });

    test('re-read only: a day whose concepts were all read on an earlier day returns none', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1', 'c2']},
        '2026-10-10': {'concepts_read': ['c1', 'c2']} // all already read
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.none);
    });

    test('quiz tier from stored tier, from missing tier (recomputed), and an invalid stored tier (recomputed)', () {
      final log = {
        '2026-10-10': {'quiz_score': 10, 'quiz_total': 10, 'quiz_tier': 'good'}, // forces 'good' via stored
        '2026-10-11': {'quiz_score': 10, 'quiz_total': 10}, // recomputed -> excellent
        '2026-10-12': {'quiz_score': 1, 'quiz_total': 10, 'quiz_tier': 'invalid'}, // recomputed -> failed
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.quizGood);
      expect(StreakEngine.heatmapCell(log, '2026-10-11', 3), HeatmapCell.quizExcellent);
      expect(StreakEngine.heatmapCell(log, '2026-10-12', 3), HeatmapCell.quizFailed);
    });

    test('quiz-only day returns the quiz cell, not none', () {
      final log = {
        '2026-10-10': {'quiz_score': 8, 'quiz_total': 10} // No concepts read
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.quizExcellent);
    });

    test('malformed entries return none and never throw', () {
      final log = {
        '2026-10-10': 'I am a string, not a map',
        '2026-10-11': {'quiz_score': 'not a number'},
        '2026-10-12': {'concepts_read': 'not a list'}
      };
      expect(() => StreakEngine.heatmapCell(log, '2026-10-10', 3), returnsNormally);
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.none);
      expect(StreakEngine.heatmapCell(log, '2026-10-11', 3), HeatmapCell.none); 
      // _hasValidQuizScore rejects non-num so it returns none
      expect(StreakEngine.heatmapCell(log, '2026-10-12', 3), HeatmapCell.none);
    });
  });

  group('DayReward pure tests', () {
    test('dayReward returns none for empty log', () {
      expect(StreakEngine.dayReward({}, '2026-10-10', 3), DayReward.none);
    });

    test('dayReward returns none for a day whose concepts were all read on earlier days', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1', 'c2', 'c3']},
        '2026-10-10': {'concepts_read': ['c1', 'c2']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-10', 3), DayReward.none);
    });

    test('dayReward returns counted for a day with one new concept', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1', 'c2']},
        '2026-10-10': {'concepts_read': ['c1', 'c3']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-10', 3), DayReward.counted);
    });

    test('dayReward returns perfect for a day with all setSize new concepts', () {
      final log = {
        '2026-10-10': {'concepts_read': ['c1', 'c2', 'c3']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-10', 3), DayReward.perfect);
    });

    test('dayReward returns none for malformed entries and never throws', () {
      final log = {
        '2026-10-10': 'corrupt string',
        '2026-10-11': {'concepts_read': 'not a list'},
      };
      expect(() => StreakEngine.dayReward(log, '2026-10-10', 3), returnsNormally);
      expect(StreakEngine.dayReward(log, '2026-10-10', 3), DayReward.none);
      expect(StreakEngine.dayReward(log, '2026-10-11', 3), DayReward.none);
    });
  });
}
