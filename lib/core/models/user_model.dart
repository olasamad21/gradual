import 'package:cloud_firestore/cloud_firestore.dart';

typedef ActivityLog = Map<String, ActivityLogEntry>;

class ActivityLogEntry {
  ActivityLogEntry({
    required this.status,
    required this.difficulty,
    required this.score,
    required this.completedDifficulties,
    required this.streakCounted,
    required this.totalCorrect,
    required this.totalQuestions,
  });

  final String status;
  final String difficulty;
  final int score;
  final List<String> completedDifficulties;
  final bool streakCounted;

  /// Accumulated correct answers across all difficulties submitted today.
  final int totalCorrect;

  /// Accumulated total questions across all difficulties submitted today.
  final int totalQuestions;

  bool hasCompleted(String difficultyId) =>
      completedDifficulties.contains(difficultyId);

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final rawList =
        json['completed_difficulties'] as List<dynamic>? ?? <dynamic>[];
    return ActivityLogEntry(
      status: json['status'] as String? ?? 'unknown',
      difficulty: json['difficulty'] as String? ?? 'junior',
      score: (json['score'] as num?)?.toInt() ?? 0,
      completedDifficulties:
      rawList.map((e) => e.toString()).toList(),
      streakCounted: json['streak_counted'] as bool? ?? false,
      totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'difficulty': difficulty,
      'score': score,
      'completed_difficulties': completedDifficulties,
      'streak_counted': streakCounted,
      'total_correct': totalCorrect,
      'total_questions': totalQuestions,
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

  /// Returns today's activity log entry if it exists.
  ActivityLogEntry? get todayEntry {
    final todayId = _todayId();
    return activityLog[todayId];
  }

  /// Whether a specific difficulty has been completed today.
  bool hasCompletedToday(String difficultyId) {
    return todayEntry?.hasCompleted(difficultyId) ?? false;
  }

  /// Whether any quiz has been submitted today.
  bool get hasQuizzedToday => todayEntry != null &&
      todayEntry!.completedDifficulties.isNotEmpty;

  String _todayId() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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