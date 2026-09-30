import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_rules.dart';
import '../errors/firestore_errors.dart';
import '../models/user_model.dart';
import '../utils/date_utils.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<AppUser?> userStream(String uid) {
    final stream = _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      try {
        return AppUser.fromDocument(snapshot);
      } catch (_) {
        return null;
      }
    });
    return FirestoreErrors.guardStream(stream);
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await FirestoreErrors.guardFuture(
      _usersCollection.doc(uid).get(),
    );
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  Future<void> createOrUpdateUser(AppUser user) {
    return FirestoreErrors.guardFuture(
      _usersCollection.doc(user.uid).set(
        {
          'email': user.email,
          'field_of_study': user.fieldOfStudy,
        },
        SetOptions(merge: true),
      ),
    );
  }

  /// Records a Saturday weekly quiz attempt and updates the week streak.
  /// Returns the new [current_streak] value written to Firestore.
  Future<int> recordWeeklyQuiz({
    required String uid,
    required DateTime serverNow,
    required int score,
    required int totalQuestions,
  }) async {
    final saturday = DateUtilsGradual.saturdayOfWeekContaining(serverNow);
    final saturdayId = DateUtilsGradual.toDateId(saturday);
    final userRef = _usersCollection.doc(uid);

    return FirestoreErrors.guardFuture(
      _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final existingData = snapshot.data() ?? <String, dynamic>{};

      final currentStreak =
          (existingData['current_streak'] as num?)?.toInt() ?? 0;
      final lastActivity =
          existingData['last_activity_date'] as Timestamp?;

      final rawLog = existingData['activity_log']
              as Map<String, dynamic>? ??
          <String, dynamic>{};
      final saturdayRaw =
          rawLog[saturdayId] as Map<String, dynamic>? ?? <String, dynamic>{};

      if (saturdayRaw['quiz_type'] == 'weekly') {
        return (existingData['current_streak'] as num?)?.toInt() ?? 0;
      }

      final tier = tierFromScore(score);
      final counts = qualifiesForStreak(score);

      int newStreak = 0;
      var streakCounted = false;

      if (counts) {
        final lastDate = DateUtilsGradual.toDateOnly(lastActivity);

        if (lastDate == null) {
          newStreak = 1;
        } else {
          final gap = DateUtilsGradual.daysBetween(lastDate, saturday);
          if (gap == 7) {
            newStreak = currentStreak + 1;
          } else {
            newStreak = 1;
          }
        }
        streakCounted = true;
      }

      final updatedSaturday = <String, dynamic>{
        'quiz_type': 'weekly',
        'score': score,
        'total_questions': totalQuestions,
        'tier': tier.id,
        'streak_counted': streakCounted,
      };

      final updatedLog = <String, dynamic>{
        ...rawLog,
        saturdayId: updatedSaturday,
      };

      final updates = <String, dynamic>{
        'activity_log': updatedLog,
        'current_streak': newStreak,
      };

      if (counts) {
        updates['last_activity_date'] =
            Timestamp.fromDate(serverNow.toUtc());
      }

      transaction.set(userRef, updates, SetOptions(merge: true));
      return newStreak;
    }),
    );
  }

  Future<void> initNewUserIfMissing(String uid) async {
    final doc = await FirestoreErrors.guardFuture(_usersCollection.doc(uid).get());
    if (!doc.exists) {
      await FirestoreErrors.guardFuture(
        _usersCollection.doc(uid).set({
          'stats_version': AppRules.currentStatsVersion,
        }, SetOptions(merge: true)),
      );
    }
  }

  Future<void> recordConceptRead({
    required String uid,
    required String conceptId,
    required String dateId,
  }) async {
    return FirestoreErrors.guardFuture(
      _usersCollection.doc(uid).update({
        FieldPath(['activity_log', dateId, 'concepts_read']): FieldValue.arrayUnion([conceptId]),
      }),
    );
  }

  Future<void> resetStatsIfNeeded(String uid) async {
    final doc = await FirestoreErrors.guardFuture(_usersCollection.doc(uid).get());
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final version = (data['stats_version'] as num?)?.toInt() ?? 0;

    if (version < AppRules.currentStatsVersion) {
      await FirestoreErrors.guardFuture(
        _usersCollection.doc(uid).update({
          'activity_log': FieldValue.delete(),
          'current_streak': FieldValue.delete(),
          'last_activity_date': FieldValue.delete(),
          'stats_version': AppRules.currentStatsVersion,
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('quiz_results_')).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
      await prefs.setBool('show_fresh_start_notice', true);
    }
  }
}

