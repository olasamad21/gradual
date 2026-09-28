import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

typedef ActivityLog = Map<String, ActivityLogEntry>;

/// Score tier for weekly Saturday quizzes (0–10 correct).
enum WeeklyScoreTier {
  excellent,
  good,
  fair,
  failed,
  missed,
  legacy,
}

extension WeeklyScoreTierX on WeeklyScoreTier {
  String get id {
    switch (this) {
      case WeeklyScoreTier.excellent:
        return 'excellent';
      case WeeklyScoreTier.good:
        return 'good';
      case WeeklyScoreTier.fair:
        return 'fair';
      case WeeklyScoreTier.failed:
        return 'failed';
      case WeeklyScoreTier.missed:
        return 'missed';
      case WeeklyScoreTier.legacy:
        return 'legacy';
    }
  }

  String get label {
    switch (this) {
      case WeeklyScoreTier.excellent:
        return 'Excellent';
      case WeeklyScoreTier.good:
        return 'Good';
      case WeeklyScoreTier.fair:
        return 'Fair';
      case WeeklyScoreTier.failed:
        return 'Failed';
      case WeeklyScoreTier.missed:
        return 'Missed';
      case WeeklyScoreTier.legacy:
        return 'Legacy';
    }
  }

  Color get color {
    switch (this) {
      case WeeklyScoreTier.excellent:
        return const Color(0xFF22C55E);
      case WeeklyScoreTier.good:
        return const Color(0xFFF59E0B);
      case WeeklyScoreTier.fair:
        return const Color(0xFFF97316);
      case WeeklyScoreTier.failed:
        return const Color(0xFFEF4444);
      case WeeklyScoreTier.missed:
        return const Color(0xFF9CA3AF);
      case WeeklyScoreTier.legacy:
        return const Color(0xFFEAECEF);
    }
  }
}

WeeklyScoreTier tierFromScore(int score) {
  if (score >= 8) return WeeklyScoreTier.excellent;
  if (score >= 5) return WeeklyScoreTier.good;
  if (score >= 3) return WeeklyScoreTier.fair;
  return WeeklyScoreTier.failed;
}

bool qualifiesForStreak(int score) => score >= 3;

WeeklyScoreTier tierFromId(String? raw) {
  switch (raw) {
    case 'excellent':
      return WeeklyScoreTier.excellent;
    case 'good':
      return WeeklyScoreTier.good;
    case 'fair':
      return WeeklyScoreTier.fair;
    case 'failed':
      return WeeklyScoreTier.failed;
    case 'missed':
      return WeeklyScoreTier.missed;
    default:
      return WeeklyScoreTier.legacy;
  }
}

class ActivityLogEntry {
  ActivityLogEntry({
    required this.quizType,
    required this.score,
    required this.totalQuestions,
    required this.tier,
    required this.streakCounted,
    this.completedDifficulties = const [],
  });

  final String quizType;
  final int score;
  final int totalQuestions;
  final WeeklyScoreTier tier;
  final bool streakCounted;

  /// Legacy daily difficulty entries (read-only compat).
  final List<String> completedDifficulties;

  bool get isWeeklyQuiz => quizType == 'weekly';

  bool get isLegacyEntry =>
      !isWeeklyQuiz && completedDifficulties.isNotEmpty;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final quizType = json['quiz_type'] as String?;
    final rawList =
        json['completed_difficulties'] as List<dynamic>? ?? <dynamic>[];
    final completedDifficulties = rawList.map((e) => e.toString()).toList();

    if (quizType == 'weekly') {
      final score = (json['score'] as num?)?.toInt() ?? 0;
      final tierRaw = json['tier'] as String?;
      return ActivityLogEntry(
        quizType: 'weekly',
        score: score,
        totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 10,
        tier: tierRaw != null ? tierFromId(tierRaw) : tierFromScore(score),
        streakCounted: json['streak_counted'] as bool? ?? false,
      );
    }

    // Legacy daily/difficulty entries
    final score = (json['total_correct'] as num?)?.toInt() ??
        (json['score'] as num?)?.toInt() ??
        0;
    return ActivityLogEntry(
      quizType: json['difficulty'] as String? ?? 'legacy',
      score: score,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 3,
      tier: WeeklyScoreTier.legacy,
      streakCounted: json['streak_counted'] as bool? ?? false,
      completedDifficulties: completedDifficulties.isNotEmpty
          ? completedDifficulties
          : json['difficulty'] != null
              ? [json['difficulty'].toString()]
              : <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    if (isWeeklyQuiz) {
      return <String, dynamic>{
        'quiz_type': 'weekly',
        'score': score,
        'total_questions': totalQuestions,
        'tier': tier.id,
        'streak_counted': streakCounted,
      };
    }
    return <String, dynamic>{
      'quiz_type': quizType,
      'score': score,
      'total_questions': totalQuestions,
      'tier': tier.id,
      'streak_counted': streakCounted,
      'completed_difficulties': completedDifficulties,
    };
  }
}

class AppUser {
  AppUser({
    required this.uid,
    required this.email,
    required this.fieldOfStudy,
    required this.currentStreak,
    required this.lastActivityDate,
    required this.activityLog,
  });

  final String uid;
  final String email;
  final String fieldOfStudy;
  final int currentStreak;
  final Timestamp? lastActivityDate;
  final ActivityLog activityLog;

  /// Live weekly streak: 0 if the user missed this week's Saturday deadline.
  int get liveStreak {
    if (currentStreak == 0 && lastActivityDate == null) return 0;

    final now = DateTime.now();
    final thisSaturday = DateUtilsGradual.saturdayOfWeekContaining(now);
    final thisSaturdayId = DateUtilsGradual.toDateId(thisSaturday);
    final deadline = DateUtilsGradual.endOfDay(thisSaturday);

    final thisWeekEntry = activityLog[thisSaturdayId];

    if (now.isAfter(deadline)) {
      if (thisWeekEntry != null &&
          thisWeekEntry.isWeeklyQuiz &&
          qualifiesForStreak(thisWeekEntry.score)) {
        return currentStreak;
      }
      return 0;
    }

    // Mon–Fri (or Saturday before deadline): streak alive if last qualifying week exists
    if (lastActivityDate == null) return 0;

    final lastQualifying = DateUtilsGradual.toDateOnly(lastActivityDate);
    if (lastQualifying == null) return 0;

    final prevSaturday = DateUtilsGradual.previousSaturday(thisSaturday);
    final gap = DateUtilsGradual.daysBetween(lastQualifying, thisSaturday);

    if (gap == 7 || gap == 0) return currentStreak;
    if (gap > 7) return 0;

    return currentStreak;
  }

  /// Entry for this week's Saturday quiz, keyed by Saturday date id.
  ActivityLogEntry? get thisWeekEntry {
    final saturday = DateUtilsGradual.saturdayOfWeekContaining(DateTime.now());
    return activityLog[DateUtilsGradual.toDateId(saturday)];
  }

  /// Whether the user has already submitted this week's weekly quiz.
  bool hasCompletedThisWeek() {
    final entry = thisWeekEntry;
    return entry != null && entry.isWeeklyQuiz;
  }

  factory AppUser.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser.fromJson(doc.id, data);
  }

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) {
    final rawLog =
        json['activity_log'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final log = <String, ActivityLogEntry>{};
    for (final entry in rawLog.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        log[entry.key] = ActivityLogEntry.fromJson(value);
      }
    }

    return AppUser(
      uid: uid,
      email: json['email'] as String? ?? '',
      fieldOfStudy:
          json['field_of_study'] as String? ?? 'software_engineering',
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      lastActivityDate: json['last_activity_date'] as Timestamp?,
      activityLog: log,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'field_of_study': fieldOfStudy,
      'current_streak': currentStreak,
      'last_activity_date': lastActivityDate,
      'activity_log': {
        for (final entry in activityLog.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  AppUser copyWith({
    String? email,
    String? fieldOfStudy,
    int? currentStreak,
    Timestamp? lastActivityDate,
    ActivityLog? activityLog,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      currentStreak: currentStreak ?? this.currentStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      activityLog: activityLog ?? this.activityLog,
    );
  }
}
