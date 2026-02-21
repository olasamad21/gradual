import 'package:cloud_firestore/cloud_firestore.dart';

typedef ActivityLog = Map<String, ActivityLogEntry>;

class ActivityLogEntry {
  ActivityLogEntry({
    required this.status,
    required this.difficulty,
    required this.score,
  });

  final String status;
  final String difficulty;
  final int score;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      status: json['status'] as String? ?? 'unknown',
      difficulty: json['difficulty'] as String? ?? 'junior',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'difficulty': difficulty,
      'score': score,
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

  factory AppUser.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser.fromJson(doc.id, data);
  }

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) {
    final rawLog = json['activity_log'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
      fieldOfStudy: json['field_of_study'] as String? ?? 'software_engineering',
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
        for (final entry in activityLog.entries) entry.key: entry.value.toJson(),
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

