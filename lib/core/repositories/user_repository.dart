import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../utils/date_utils.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Live stream of the user's Firestore document, mapped to [AppUser].
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

  /// Updates streak and activity log for the given [uid] and [date].
  ///
  /// This is a simple placeholder; streak rules can be refined later
  /// (e.g., ensuring consecutive days using server time).
  Future<void> recordActivity({
    required String uid,
    required DateTime serverNow,
    required String status,
    required String difficulty,
    required int score,
  }) async {
    final todayId = DateUtilsGradual.toDateId(serverNow);
    final userRef = _usersCollection.doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final existingData =
          snapshot.data() ?? <String, dynamic>{};

      final currentStreak =
          (existingData['current_streak'] as num?)?.toInt() ?? 0;
      final lastActivity =
          existingData['last_activity_date'] as Timestamp?;

      final lastDate = DateUtilsGradual.toDateOnly(lastActivity);
      final serverDate =
          DateTime.utc(serverNow.year, serverNow.month, serverNow.day);

      int newStreak = currentStreak;
      if (lastDate == null) {
        newStreak = 1;
      } else {
        final difference = serverDate.difference(lastDate).inDays;
        if (difference == 0) {
          newStreak = currentStreak;
        } else if (difference == 1) {
          newStreak = currentStreak + 1;
        } else {
          newStreak = 1;
        }
      }

      final activityLog =
          (existingData['activity_log'] as Map<String, dynamic>? ??
              <String, dynamic>{})
            ..[todayId] = <String, dynamic>{
              'status': status,
              'difficulty': difficulty,
              'score': score,
            };

      transaction.set(
        userRef,
        <String, dynamic>{
          'current_streak': newStreak,
          'last_activity_date': Timestamp.fromDate(serverNow.toUtc()),
          'activity_log': activityLog,
        },
        SetOptions(merge: true),
      );
    });
  }
}

