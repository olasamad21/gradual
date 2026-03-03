import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../utils/date_utils.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<AppUser?> userStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return AppUser.fromDocument(snapshot);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDocument(doc);
  }

  Future<void> createOrUpdateUser(AppUser user) {
    return _usersCollection.doc(user.uid).set(
      user.toJson(),
      SetOptions(merge: true),
    );
  }

  Future<void> recordActivity({
    required String uid,
    required DateTime serverNow,
    required String status,
    required String difficulty,
    required int score,
    required int totalQuestions,
  }) async {
    final todayId = DateUtilsGradual.toDateId(serverNow);
    final userRef = _usersCollection.doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final existingData = snapshot.data() ?? <String, dynamic>{};

      final currentStreak =
          (existingData['current_streak'] as num?)?.toInt() ?? 0;
      final lastActivity =
      existingData['last_activity_date'] as Timestamp?;

      final rawLog = existingData['activity_log']
      as Map<String, dynamic>? ??
          <String, dynamic>{};
      final todayRaw =
          rawLog[todayId] as Map<String, dynamic>? ?? <String, dynamic>{};

      final completedToday =
          todayRaw['completed_difficulties'] as List<dynamic>? ??
              <dynamic>[];
      final isFirstSubmissionToday = completedToday.isEmpty;

      // Already submitted this category today — skip
      if (completedToday.contains(difficulty)) return;

      // Calculate streak only on first submission of the day
      int newStreak = currentStreak;
      if (isFirstSubmissionToday) {
        final lastDate = DateUtilsGradual.toDateOnly(lastActivity);
        final serverDate =
        DateTime.utc(serverNow.year, serverNow.month, serverNow.day);

        if (lastDate == null) {
          newStreak = 1;
        } else {
          final difference = serverDate.difference(lastDate).inDays;
          if (difference == 1) {
            newStreak = currentStreak + 1;
          } else if (difference > 1) {
            newStreak = 1;
          }
        }
      }

      final updatedDifficulties = [...completedToday, difficulty];

      // Accumulate totals for all-time correct % calculation
      final existingTotalCorrect =
          (todayRaw['total_correct'] as num?)?.toInt() ?? 0;
      final existingTotalQuestions =
          (todayRaw['total_questions'] as num?)?.toInt() ?? 0;

      final updatedToday = <String, dynamic>{
        ...todayRaw,
        'status': status,
        'difficulty': difficulty,
        'score': score,
        'total_correct': existingTotalCorrect + score,
        'total_questions': existingTotalQuestions + totalQuestions,
        'completed_difficulties': updatedDifficulties,
        'streak_counted': isFirstSubmissionToday,
      };

      final updatedLog = <String, dynamic>{
        ...rawLog,
        todayId: updatedToday,
      };

      final updates = <String, dynamic>{
        'activity_log': updatedLog,
      };

      if (isFirstSubmissionToday) {
        updates['current_streak'] = newStreak;
        updates['last_activity_date'] =
            Timestamp.fromDate(serverNow.toUtc());
      }

      transaction.set(userRef, updates, SetOptions(merge: true));
    });
  }
}