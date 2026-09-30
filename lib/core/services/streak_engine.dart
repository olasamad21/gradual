import '../config/app_rules.dart';

enum QuizStatusType { notYetOpen, needMoreConcepts, available, completed }

class QuizStatus {
  const QuizStatus(this.type, [this.conceptsNeeded = 0]);
  final QuizStatusType type;
  final int conceptsNeeded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizStatus &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          conceptsNeeded == other.conceptsNeeded;

  @override
  int get hashCode => type.hashCode ^ conceptsNeeded.hashCode;
}

abstract final class StreakEngine {
  static String _dateId(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Processes the log chronologically. A day counts if it introduces
  /// at least one concept ID not read on any previous day.
  static Set<String> countedDays(Map<String, dynamic> log) {
    final sortedKeys = log.keys.toList()..sort();
    final seen = <String>{};
    final counted = <String>{};

    for (final date in sortedKeys) {
      final entry = log[date];
      if (entry is! Map) continue;

      final conceptsRaw = entry['concepts_read'];
      if (conceptsRaw is! List) continue;

      var hasNew = false;
      final dayConcepts = <String>{};

      for (final c in conceptsRaw) {
        if (c is String) {
          dayConcepts.add(c);
          if (!seen.contains(c)) hasNew = true;
        }
      }

      if (hasNew) {
        seen.addAll(dayConcepts);
        counted.add(date);
      }
    }

    return counted;
  }

  /// Computes the current streak from today, walking backwards one day at a time.
  static int currentStreak(Map<String, dynamic> log, DateTime today) {
    final counted = countedDays(log);
    var streak = 0;
    
    var cursor = DateTime(today.year, today.month, today.day);
    
    // Alive via yesterday if today is unlogged
    if (!counted.contains(_dateId(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    while (counted.contains(_dateId(cursor))) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    
    return streak;
  }

  static int longestStreak(Map<String, dynamic> log) {
    final counted = countedDays(log).toList()..sort();
    if (counted.isEmpty) return 0;

    var maxStreak = 1;
    var currentStreak = 1;

    for (var i = 1; i < counted.length; i++) {
      final prevParts = counted[i - 1].split('-');
      final currParts = counted[i].split('-');
      if (prevParts.length == 3 && currParts.length == 3) {
        final prevDt = DateTime(int.parse(prevParts[0]), int.parse(prevParts[1]), int.parse(prevParts[2]));
        // Next day is prevDt + 1 day
        final expectedNext = DateTime(prevDt.year, prevDt.month, prevDt.day + 1);
        final expectedNextStr = _dateId(expectedNext);
        
        if (counted[i] == expectedNextStr) {
          currentStreak++;
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
          }
        } else {
          currentStreak = 1;
        }
      }
    }
    return maxStreak;
  }

  static bool isPerfectDay(Map<String, dynamic> log, String id, int setSize) {
    final counted = countedDays(log);
    if (!counted.contains(id)) return false;

    final entry = log[id];
    if (entry is! Map) return false;
    final conceptsRaw = entry['concepts_read'];
    if (conceptsRaw is! List) return false;

    final distinctIds = conceptsRaw.whereType<String>().toSet();
    return distinctIds.length >= setSize;
  }

  static String weekStartId(DateTime today) {
    final local = DateTime(today.year, today.month, today.day);
    // In Dart, Monday = 1, Sunday = 7
    final daysSinceMonday = local.weekday - 1;
    final monday = DateTime(local.year, local.month, local.day - daysSinceMonday);
    return _dateId(monday);
  }

  static List<String> _weekDateIds(DateTime today) {
    final local = DateTime(today.year, today.month, today.day);
    final daysSinceMonday = local.weekday - 1;
    final monday = DateTime(local.year, local.month, local.day - daysSinceMonday);
    
    return List.generate(7, (i) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      return _dateId(d);
    });
  }

  static Set<String> conceptsReadInWeek(Map<String, dynamic> log, DateTime today) {
    final weekIds = _weekDateIds(today);
    final result = <String>{};

    for (final id in weekIds) {
      final entry = log[id];
      if (entry is Map) {
        final conceptsRaw = entry['concepts_read'];
        if (conceptsRaw is List) {
          result.addAll(conceptsRaw.whereType<String>());
        }
      }
    }
    return result;
  }

  static Set<String> allConceptsRead(Map<String, dynamic> log) {
    final result = <String>{};
    for (final entry in log.values) {
      if (entry is Map) {
        final conceptsRaw = entry['concepts_read'];
        if (conceptsRaw is List) {
          result.addAll(conceptsRaw.whereType<String>());
        }
      }
    }
    return result;
  }

  static bool quizWindowOpen(DateTime today) {
    return AppRules.quizWindowWeekdays.contains(today.weekday);
  }

  static bool quizTakenThisWeek(Map<String, dynamic> log, DateTime today) {
    final weekIds = _weekDateIds(today);
    for (final id in weekIds) {
      final entry = log[id];
      if (entry is Map) {
        // Fallback for legacy format 'score' alongside new 'quiz_score'
        if (entry['quiz_score'] != null || entry['score'] != null) {
          return true;
        }
      }
    }
    return false;
  }

  static QuizStatus quizStatus(Map<String, dynamic> log, DateTime today) {
    final isOpen = quizWindowOpen(today);
    if (!isOpen) {
      return const QuizStatus(QuizStatusType.notYetOpen);
    }

    final readThisWeek = conceptsReadInWeek(log, today).length;
    if (readThisWeek < AppRules.quizMinConceptsThisWeek) {
      return QuizStatus(QuizStatusType.needMoreConcepts, AppRules.quizMinConceptsThisWeek - readThisWeek);
    }

    if (quizTakenThisWeek(log, today)) {
      return const QuizStatus(QuizStatusType.completed);
    }

    return const QuizStatus(QuizStatusType.available);
  }
}
