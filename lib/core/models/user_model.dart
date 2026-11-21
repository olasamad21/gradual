import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/streak_engine.dart';

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
    this.conceptsRead = const [],
    this.quizScore,
    this.quizTotal,
    this.quizTier,
  });

  final String quizType;
  final int score;
  final int totalQuestions;
  final WeeklyScoreTier tier;
  final bool streakCounted;

  /// Legacy daily difficulty entries (read-only compat).
  final List<String> completedDifficulties;
  final List<String> conceptsRead;
  final int? quizScore;
  final int? quizTotal;
  final String? quizTier;

  bool get isWeeklyQuiz => quizType == 'weekly';

  bool get isLegacyEntry =>
      !isWeeklyQuiz && completedDifficulties.isNotEmpty;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final quizType = json['quiz_type'] as String?;
    final rawList =
        json['completed_difficulties'] as List<dynamic>? ?? <dynamic>[];
    final completedDifficulties = rawList.map((e) => e.toString()).toList();

    final rawConcepts = json['concepts_read'] as List<dynamic>? ?? <dynamic>[];
    final conceptsRead = rawConcepts.map((e) => e.toString()).toList();

    final rawQuizScore = json['quiz_score'];
    final rawQuizTotal = json['quiz_total'];
    final isNewStyleQuiz = rawQuizScore is num &&
        rawQuizTotal is num &&
        rawQuizScore >= 0 &&
        rawQuizTotal > 0;

    if (isNewStyleQuiz) {
      final score = rawQuizScore.toInt();
      final totalQuestions = rawQuizTotal.toInt();
      final rawQuizTier = json['quiz_tier'] as String?;
      final tier = (rawQuizTier != null &&
              const ['excellent', 'good', 'fair', 'failed', 'missed'].contains(rawQuizTier.toLowerCase()))
          ? tierFromId(rawQuizTier)
          : tierFromId(StreakEngine.quizTier(score, totalQuestions));

      return ActivityLogEntry(
        quizType: 'weekly',
        score: score,
        totalQuestions: totalQuestions,
        tier: tier,
        streakCounted: json['streak_counted'] as bool? ?? false,
        conceptsRead: conceptsRead,
        quizScore: score,
        quizTotal: totalQuestions,
        quizTier: tier.id,
      );
    }

    if (quizType == 'weekly') {
      final rawScore = json['score'];
      final rawTotal = json['total_questions'];
      // Malformed values check: negative numbers are not counted as weekly quiz
      if ((rawScore is num && rawScore < 0) || (rawTotal is num && rawTotal <= 0)) {
        return ActivityLogEntry(
          quizType: 'legacy',
          score: 0,
          totalQuestions: 0,
          tier: WeeklyScoreTier.legacy,
          streakCounted: false,
          conceptsRead: conceptsRead,
        );
      }
      final score = (rawScore as num?)?.toInt() ?? 0;
      final total = (rawTotal as num?)?.toInt() ?? 10;
      final tierRaw = json['tier'] as String?;
      return ActivityLogEntry(
        quizType: 'weekly',
        score: score,
        totalQuestions: total,
        tier: tierRaw != null ? tierFromId(tierRaw) : tierFromScore(score),
        streakCounted: json['streak_counted'] as bool? ?? false,
        conceptsRead: conceptsRead,
        quizScore: (rawQuizScore is num && rawQuizScore >= 0)
            ? rawQuizScore.toInt()
            : score,
        quizTotal: (rawQuizTotal is num && rawQuizTotal > 0)
            ? rawQuizTotal.toInt()
            : total,
        quizTier: json['quiz_tier'] as String?,
      );
    }

    // Legacy daily/difficulty entries OR concept-only entries
    final score = (json['total_correct'] as num?)?.toInt() ??
        (json['score'] as num?)?.toInt() ??
        0;
    return ActivityLogEntry(
      quizType: quizType ?? json['difficulty'] as String? ?? 'legacy',
      score: score,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 3,
      tier: WeeklyScoreTier.legacy,
      streakCounted: json['streak_counted'] as bool? ?? false,
      completedDifficulties: completedDifficulties.isNotEmpty
          ? completedDifficulties
          : json['difficulty'] != null
              ? [json['difficulty'].toString()]
              : <String>[],
      conceptsRead: conceptsRead,
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
        if (quizScore != null) 'quiz_score': quizScore,
        if (quizTotal != null) 'quiz_total': quizTotal,
        if (quizTier != null) 'quiz_tier': quizTier,
        if (conceptsRead.isNotEmpty) 'concepts_read': conceptsRead,
      };
    }
    return <String, dynamic>{
      'quiz_type': quizType,
      'score': score,
      'total_questions': totalQuestions,
      'tier': tier.id,
      'streak_counted': streakCounted,
      'completed_difficulties': completedDifficulties,
      if (conceptsRead.isNotEmpty) 'concepts_read': conceptsRead,
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
    this.rawActivityLog = const <String, dynamic>{},
    this.savedConcepts = const <String, int>{},
  });

  final String uid;
  final String email;
  final String fieldOfStudy;
  final int currentStreak;
  final Timestamp? lastActivityDate;
  final ActivityLog activityLog;
  final Map<String, dynamic> rawActivityLog;
  final Map<String, int> savedConcepts;

  List<String> get savedConceptIdsNewestFirst {
    final entries = savedConcepts.entries.toList();
    entries.sort((a, b) {
      final valueComp = b.value.compareTo(a.value);
      if (valueComp != 0) return valueComp;
      return a.key.compareTo(b.key);
    });
    return entries.map((e) => e.key).toList();
  }

  int streakAt(DateTime today) => StreakEngine.currentStreak(rawActivityLog, today);

  int get liveStreak => streakAt(DateTime.now());

  factory AppUser.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser.fromJson(doc.id, data);
  }

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) {
    final dynamic rawActivity = json['activity_log'];
    final Map<String, dynamic> rawLog;
    if (rawActivity is Map<String, dynamic>) {
      rawLog = rawActivity;
    } else if (rawActivity is Map) {
      rawLog = Map<String, dynamic>.from(rawActivity);
    } else {
      rawLog = <String, dynamic>{};
    }

    final log = <String, ActivityLogEntry>{};
    for (final entry in rawLog.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        log[entry.key] = ActivityLogEntry.fromJson(value);
      } else if (value is Map) {
        log[entry.key] = ActivityLogEntry.fromJson(Map<String, dynamic>.from(value));
      }
    }

    final rawSaved = json['saved_concepts'];
    final savedConcepts = <String, int>{};
    if (rawSaved is Map) {
      for (final entry in rawSaved.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && key.isNotEmpty && value is num) {
          savedConcepts[key] = value.toInt();
        }
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
      rawActivityLog: rawLog,
      savedConcepts: savedConcepts,
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
    Map<String, int>? savedConcepts,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      currentStreak: currentStreak ?? this.currentStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      activityLog: activityLog ?? this.activityLog,
      savedConcepts: savedConcepts ?? this.savedConcepts,
    );
  }
}
