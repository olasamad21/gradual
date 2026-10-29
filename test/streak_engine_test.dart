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
      // 2026-10-06 is Tuesday, 2026-10-07 is Wednesday
      final log = {
        '2026-10-06': {
          'concepts_read': ['c1']
        }
      };
      final today = DateTime(2026, 10, 7);
      expect(StreakEngine.currentStreak(log, today), 1);
    });

    test('one-day gap resets streak', () {
      // 2026-10-06 is Tuesday, 2026-10-08 is Thursday (Wednesday 07 is missing)
      final log = {
        '2026-10-06': {
          'concepts_read': ['c1']
        }
      };
      final today = DateTime(2026, 10, 8);
      expect(StreakEngine.currentStreak(log, today), 0);
    });

    test('quiz-only day does not count towards streak', () {
      // 2026-10-06 is Tuesday, 2026-10-07 is Wednesday
      final log = {
        '2026-10-06': {
          'quiz_score': 5
        }
      };
      final today = DateTime(2026, 10, 7);
      expect(StreakEngine.currentStreak(log, today), 0);
    });

    test('day repeating only already-read concepts does not count', () {
      // 2026-10-06 is Tuesday, 2026-10-07 is Wednesday, 2026-10-08 is Thursday
      final log = {
        '2026-10-06': {
          'concepts_read': ['c1', 'c2']
        },
        '2026-10-07': {
          'concepts_read': ['c1'] // duplicate from yesterday
        }
      };
      final today = DateTime(2026, 10, 8);
      expect(StreakEngine.currentStreak(log, today), 0); // 07 didn't count, so 08 is broken
      expect(StreakEngine.longestStreak(log), 1);
    });

    test('day with 1 new + 2 old concepts counts', () {
      // 2026-10-06 is Tuesday, 2026-10-07 is Wednesday
      final log = {
        '2026-10-06': {
          'concepts_read': ['c1', 'c2']
        },
        '2026-10-07': {
          'concepts_read': ['c1', 'c2', 'c3'] // c3 is new
        }
      };
      final today = DateTime(2026, 10, 7);
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
      // 2026-03-06 is Friday before spring forward; 2026-03-09 is Monday after spring forward
      final log = {
        '2026-03-06': {'concepts_read': ['c1']},
        '2026-03-09': {'concepts_read': ['c2']},
      };
      final today = DateTime(2026, 3, 9);
      expect(StreakEngine.currentStreak(log, today), 2);
      expect(StreakEngine.longestStreak(log), 2);
    });

    test('DST dates (Fall Back: 2026-11-01)', () {
      // 2026-10-30 is Friday before fall back; 2026-11-02 is Monday after fall back
      final log = {
        '2026-10-30': {'concepts_read': ['c1']},
        '2026-11-02': {'concepts_read': ['c2']},
      };
      final today = DateTime(2026, 11, 2);
      expect(StreakEngine.currentStreak(log, today), 2);
      expect(StreakEngine.longestStreak(log), 2);
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

    test('weekend date with concepts read returns none', () {
      final log = {
        '2026-10-10': {'concepts_read': ['c1', 'c2', 'c3']} // Saturday
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-10', 3), HeatmapCell.none);
    });

    test('partial: a weekday with 1 concept read', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1']} // Friday
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-09', 3), HeatmapCell.partial);
    });

    test('perfect: 3 concepts read (setSize 3), and NOT perfect with 2 on weekdays', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1', 'c2']},
        '2026-10-09': {'concepts_read': ['c1', 'c2', 'c3']}
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-08', 3), HeatmapCell.partial);
      expect(StreakEngine.heatmapCell(log, '2026-10-09', 3), HeatmapCell.perfect);
    });

    test('re-read only: a day whose concepts were all read on an earlier day returns none', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1', 'c2']},
        '2026-10-09': {'concepts_read': ['c1', 'c2']} // all already read
      };
      expect(StreakEngine.heatmapCell(log, '2026-10-09', 3), HeatmapCell.none);
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

    test('dayReward returns none for a weekend date even with new concepts', () {
      final log = {
        '2026-10-10': {'concepts_read': ['c1', 'c2', 'c3']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-10', 3), DayReward.none);
      expect(StreakEngine.isPerfectDay(log, '2026-10-10', 3), isFalse);
    });

    test('dayReward returns none for a day whose concepts were all read on earlier days', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1', 'c2', 'c3']},
        '2026-10-09': {'concepts_read': ['c1', 'c2']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-09', 3), DayReward.none);
    });

    test('dayReward returns counted for a weekday with one new concept', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1', 'c2']},
        '2026-10-09': {'concepts_read': ['c1', 'c3']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-09', 3), DayReward.counted);
    });

    test('dayReward returns perfect for a weekday with all setSize new concepts', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1', 'c2', 'c3']},
      };
      expect(StreakEngine.dayReward(log, '2026-10-09', 3), DayReward.perfect);
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

  group('StreakEngine Weekend Review Option 2 rules', () {
    test('isWeekendDateId correctly identifies Saturday and Sunday and handles invalid input', () {
      expect(StreakEngine.isWeekendDateId('2026-10-10'), isTrue); // Saturday
      expect(StreakEngine.isWeekendDateId('2026-10-11'), isTrue); // Sunday
      expect(StreakEngine.isWeekendDateId('2026-10-17'), isTrue); // Saturday
      expect(StreakEngine.isWeekendDateId('2026-10-18'), isTrue); // Sunday
      expect(StreakEngine.isWeekendDateId('2026-03-07'), isTrue); // Saturday
      expect(StreakEngine.isWeekendDateId('2026-03-08'), isTrue); // Sunday
      expect(StreakEngine.isWeekendDateId('2026-10-31'), isTrue); // Saturday
      expect(StreakEngine.isWeekendDateId('2026-11-01'), isTrue); // Sunday

      expect(StreakEngine.isWeekendDateId('2026-10-05'), isFalse); // Monday
      expect(StreakEngine.isWeekendDateId('2026-10-06'), isFalse); // Tuesday
      expect(StreakEngine.isWeekendDateId('2026-10-07'), isFalse); // Wednesday
      expect(StreakEngine.isWeekendDateId('2026-10-08'), isFalse); // Thursday
      expect(StreakEngine.isWeekendDateId('2026-10-09'), isFalse); // Friday
      expect(StreakEngine.isWeekendDateId('2026-10-12'), isFalse); // Monday

      expect(StreakEngine.isWeekendDateId(''), isFalse);
      expect(StreakEngine.isWeekendDateId('not-a-date'), isFalse);
      expect(StreakEngine.isWeekendDateId('2026-10'), isFalse);
      expect(StreakEngine.isWeekendDateId('2026/10/10'), isFalse);
    });

    test('countedDays never contains a Saturday or Sunday key even when it has new concepts; weekday behaviour unchanged', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1']}, // Thursday (counted)
        '2026-10-09': {'concepts_read': ['c2']}, // Friday (counted)
        '2026-10-10': {'concepts_read': ['c3']}, // Saturday (new concept, but weekend -> not counted)
        '2026-10-11': {'concepts_read': ['c4']}, // Sunday (new concept, but weekend -> not counted)
        '2026-10-12': {'concepts_read': ['c5']}, // Monday (counted)
      };

      final counted = StreakEngine.countedDays(log);
      expect(counted.contains('2026-10-08'), isTrue);
      expect(counted.contains('2026-10-09'), isTrue);
      expect(counted.contains('2026-10-10'), isFalse);
      expect(counted.contains('2026-10-11'), isFalse);
      expect(counted.contains('2026-10-12'), isTrue);
      expect(counted, {'2026-10-08', '2026-10-09', '2026-10-12'});
    });

    test('weekend reads still update seen set so repeating weekend concepts on Monday does not count', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1']}, // Friday (counted)
        '2026-10-10': {'concepts_read': ['c2']}, // Saturday (not counted, but c2 is now seen)
        '2026-10-12': {'concepts_read': ['c2']}, // Monday (only has c2, duplicate -> not counted)
      };

      final counted = StreakEngine.countedDays(log);
      expect(counted, {'2026-10-09'});
    });

    test('currentStreak: Mon to Fri counted, today Sunday: 5', () {
      final log = {
        '2026-10-05': {'concepts_read': ['c1']}, // Mon
        '2026-10-06': {'concepts_read': ['c2']}, // Tue
        '2026-10-07': {'concepts_read': ['c3']}, // Wed
        '2026-10-08': {'concepts_read': ['c4']}, // Thu
        '2026-10-09': {'concepts_read': ['c5']}, // Fri
      };
      final todaySunday = DateTime(2026, 10, 11);
      expect(StreakEngine.currentStreak(log, todaySunday), 5);
    });

    test('currentStreak: Mon to Fri counted, today next Monday unread: 5', () {
      final log = {
        '2026-10-05': {'concepts_read': ['c1']}, // Mon
        '2026-10-06': {'concepts_read': ['c2']}, // Tue
        '2026-10-07': {'concepts_read': ['c3']}, // Wed
        '2026-10-08': {'concepts_read': ['c4']}, // Thu
        '2026-10-09': {'concepts_read': ['c5']}, // Fri
      };
      final todayNextMonday = DateTime(2026, 10, 12);
      expect(StreakEngine.currentStreak(log, todayNextMonday), 5);
    });

    test('currentStreak: Same plus next Monday read: 6', () {
      final log = {
        '2026-10-05': {'concepts_read': ['c1']}, // Mon
        '2026-10-06': {'concepts_read': ['c2']}, // Tue
        '2026-10-07': {'concepts_read': ['c3']}, // Wed
        '2026-10-08': {'concepts_read': ['c4']}, // Thu
        '2026-10-09': {'concepts_read': ['c5']}, // Fri
        '2026-10-12': {'concepts_read': ['c6']}, // Next Mon
      };
      final todayNextMonday = DateTime(2026, 10, 12);
      expect(StreakEngine.currentStreak(log, todayNextMonday), 6);
    });

    test('currentStreak: Friday not counted, today Saturday: 0', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1']}, // Thursday
        // Friday 2026-10-09 not logged
      };
      final todaySaturday = DateTime(2026, 10, 10);
      expect(StreakEngine.currentStreak(log, todaySaturday), 0);
    });

    test('currentStreak: Only Saturday read, today Sunday: 0', () {
      final log = {
        '2026-10-10': {'concepts_read': ['c1']}, // Sat
      };
      final todaySunday = DateTime(2026, 10, 11);
      expect(StreakEngine.currentStreak(log, todaySunday), 0);
    });

    test('currentStreak: Empty log: 0', () {
      final today = DateTime(2026, 10, 11);
      expect(StreakEngine.currentStreak({}, today), 0);
    });

    test('longestStreak: A run Thursday, Friday, next Monday, next Tuesday is 4', () {
      final log = {
        '2026-10-08': {'concepts_read': ['c1']}, // Thursday
        '2026-10-09': {'concepts_read': ['c2']}, // Friday
        '2026-10-12': {'concepts_read': ['c3']}, // Monday
        '2026-10-13': {'concepts_read': ['c4']}, // Tuesday
      };
      expect(StreakEngine.longestStreak(log), 4);
    });

    test('weekend reads do not add to streak but do appear in conceptsReadInWeek and can unlock quizStatus', () {
      final log = {
        '2026-10-09': {'concepts_read': ['c1', 'c2']}, // Friday (2 reads)
        '2026-10-10': {'concepts_read': ['c3', 'c4', 'c5']}, // Saturday (3 reads)
      };

      final todaySaturday = DateTime(2026, 10, 10);

      // Streak only counts Friday (streak = 1)
      expect(StreakEngine.currentStreak(log, todaySaturday), 1);
      expect(StreakEngine.countedDays(log), {'2026-10-09'});

      // But conceptsReadInWeek collects all 5 concepts!
      final weekConcepts = StreakEngine.conceptsReadInWeek(log, todaySaturday);
      expect(weekConcepts.length, 5);
      expect(weekConcepts, {'c1', 'c2', 'c3', 'c4', 'c5'});

      // And quizStatus is available on Saturday with 5 concepts!
      final status = StreakEngine.quizStatus(log, todaySaturday);
      expect(status.type, QuizStatusType.available);
    });

    test('dayReward and isPerfectDay are none and false on weekend; heatmapCell is none for reads and quiz cell for quiz_score', () {
      final weekendLog = {
        '2026-10-10': {'concepts_read': ['c1', 'c2', 'c3']},
      };
      expect(StreakEngine.dayReward(weekendLog, '2026-10-10', 3), DayReward.none);
      expect(StreakEngine.isPerfectDay(weekendLog, '2026-10-10', 3), isFalse);
      expect(StreakEngine.heatmapCell(weekendLog, '2026-10-10', 3), HeatmapCell.none);

      final weekendQuizLog = {
        '2026-10-10': {'quiz_score': 10, 'quiz_total': 10},
      };
      expect(StreakEngine.heatmapCell(weekendQuizLog, '2026-10-10', 3), HeatmapCell.quizExcellent);
    });
  });
}
