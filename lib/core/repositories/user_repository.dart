import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_rules.dart';
import '../errors/firestore_errors.dart';
import '../utils/date_utils.dart';
import '../../features/quiz/quiz_models.dart';
import '../models/user_model.dart';
import '../services/streak_engine.dart';

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

  Future<QuizSaveResult> saveQuizScore({
    required String uid,
    required String dateId,
    required int score,
    required int total,
    required String tier,
  }) async {
    final docRef = _usersCollection.doc(uid);
    return FirestoreErrors.guardFuture(
      _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) throw StateError('User document not found');
        final data = doc.data()!;
        final rawLog = data['activity_log'] as Map<String, dynamic>? ?? {};

        final submitDate = DateUtilsGradual.dateFromId(dateId);
        
        if (StreakEngine.quizTakenThisWeek(rawLog, submitDate)) {
          return QuizSaveResult.alreadyTaken;
        }

        transaction.update(docRef, {
          'activity_log.$dateId.quiz_score': score,
          'activity_log.$dateId.quiz_total': total,
          'activity_log.$dateId.quiz_tier': tier,
        });
        
        return QuizSaveResult.saved;
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
        'activity_log.$dateId.concepts_read': FieldValue.arrayUnion([conceptId]),
      }),
    );
  }

  Future<void> setConceptSaved({
    required String uid,
    required String conceptId,
    required bool saved,
    required int savedAtMillis,
  }) async {
    return FirestoreErrors.guardFuture(
      _usersCollection.doc(uid).update({
        FieldPath(['saved_concepts', conceptId]):
            saved ? savedAtMillis : FieldValue.delete(),
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