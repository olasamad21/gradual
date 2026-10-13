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

  static bool _hasValidQuizScore(dynamic entry) {
    if (entry is! Map) return false;
    return entry['quiz_score'] is num || entry['score'] is num;
  }

  static String? quizDateIdInWeek(Map<String, dynamic> log, DateTime today) {
    final local = DateTime(today.year, today.month, today.day);
    final daysSinceMonday = local.weekday - 1;
    final monday = DateTime(local.year, local.month, local.day - daysSinceMonday);
    
    for (int i = 0; i < 7; i++) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      final id = _dateId(d);
      if (_hasValidQuizScore(log[id])) {
        return id;
      }
    }
    return null;
  }

  static bool quizTakenThisWeek(Map<String, dynamic> log, DateTime today) {
    return quizDateIdInWeek(log, today) != null;
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
  static String quizTier(int score, int total) {
    if (total <= 0) return 'failed';
    final pct = score / total;
    if (pct >= 0.8) return 'excellent';
    if (pct >= 0.5) return 'good';
    if (pct >= 0.3) return 'fair';
    return 'failed';
  }

  static bool dayCountsForStreak(Map<String, dynamic> log, String dateId) {
    try {
      return countedDays(log).contains(dateId);
    } catch (_) {
      return false;
    }
  }

  static DayReward dayReward(Map<String, dynamic> log, String dateId, int setSize) {
    try {
      if (isPerfectDay(log, dateId, setSize)) {
        return DayReward.perfect;
      }
      if (dayCountsForStreak(log, dateId)) {
        return DayReward.counted;
      }
    } catch (_) {
      // Never throw on malformed data
    }
    return DayReward.none;
  }

  static HeatmapCell heatmapCell(Map<String, dynamic> log, String dateId, int setSize) {
    try {
      final entry = log[dateId];
      if (entry != null && _hasValidQuizScore(entry)) {
        final rawTier = entry['quiz_tier'];
        String tier;
        if (rawTier is String && const ['excellent', 'good', 'fair', 'failed'].contains(rawTier)) {
          tier = rawTier;
        } else {
          final score = (entry['quiz_score'] is num) ? (entry['quiz_score'] as num).toInt() : 0;
          final total = (entry['quiz_total'] is num) ? (entry['quiz_total'] as num).toInt() : 0;
          tier = quizTier(score, total);
        }
        
        switch (tier) {
          case 'excellent': return HeatmapCell.quizExcellent;
          case 'good': return HeatmapCell.quizGood;
          case 'fair': return HeatmapCell.quizFair;
          default: return HeatmapCell.quizFailed;
        }
      }

      if (isPerfectDay(log, dateId, setSize)) {
        return HeatmapCell.perfect;
      }

      final counted = countedDays(log);
      if (counted.contains(dateId)) {
        return HeatmapCell.partial;
      }
    } catch (_) {
      // Never throw on malformed data
    }
    
    return HeatmapCell.none;
  }
}

enum DayReward {
  none,
  counted,
  perfect,
}

bool dayCountsForStreak(Map<String, dynamic> log, String dateId) =>
    StreakEngine.dayCountsForStreak(log, dateId);

DayReward dayReward(Map<String, dynamic> log, String dateId, int setSize) =>
    StreakEngine.dayReward(log, dateId, setSize);

enum HeatmapCell {
  none,
  partial,
  perfect,
  quizExcellent,
  quizGood,
  quizFair,
  quizFailed
}
