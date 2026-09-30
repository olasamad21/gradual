import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/firestore_errors.dart';
import '../models/daily_content_model.dart';
import '../models/weekly_quiz_model.dart';
import '../models/concept_model.dart';
import '../utils/date_utils.dart';

class TodaysConceptsResult {
  const TodaysConceptsResult({
    this.dailySet,
    this.concepts = const [],
    this.isFallback = false,
  });

  final DailySet? dailySet;
  final List<Concept> concepts;
  final bool isFallback;
}

class ContentRepository {
  ContentRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collectionForField(
    String fieldOfStudy,
  ) {
    // For MVP we support only software engineering, but this allows
    // easy expansion (e.g., content_nursing, content_law, ...).
    final key = fieldOfStudy.toLowerCase().replaceAll(' ', '_');
    return _firestore.collection('content_$key');
  }

  CollectionReference<Map<String, dynamic>> _quizzesCollectionForField(
    String fieldOfStudy,
  ) {
    final key = fieldOfStudy.toLowerCase().replaceAll(' ', '_');
    return _firestore.collection('quizzes_$key');
  }

  Future<DailyContent?> getContentForDate({
    required String fieldOfStudy,
    required DateTime date,
  }) async {
    final dateId = DateUtilsGradual.toDateId(date);
    final snapshot = await FirestoreErrors.guardFuture(
      _collectionForField(fieldOfStudy).doc(dateId).get(),
    );
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;

    data['date_id'] = dateId;

    return DailyContent.fromJson(data);
  }

  Future<WeeklyQuiz?> getWeeklyQuiz({
    required String fieldOfStudy,
    required DateTime date,
  }) async {
    final dateId = DateUtilsGradual.toDateId(date);
    final snapshot = await FirestoreErrors.guardFuture(
      _quizzesCollectionForField(fieldOfStudy).doc(dateId).get(),
    );
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;

    return WeeklyQuiz.fromJson(data);
  }

  Future<List<DailyContent>> getHistory({
    required String fieldOfStudy,
    int limit = 30,
  }) async {
    final querySnapshot = await FirestoreErrors.guardFuture(
      _collectionForField(fieldOfStudy)
          .orderBy('date_id', descending: true)
          .limit(limit)
          .get(),
    );

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['date_id'] = doc.id;  // ← ADD THIS
      return DailyContent.fromJson(data);
    }).toList();
  }

  CollectionReference<Map<String, dynamic>> _conceptsCollectionForField(String fieldOfStudy) {
    final key = fieldOfStudy.toLowerCase().replaceAll(' ', '_');
    return _firestore.collection('concepts_$key');
  }

  CollectionReference<Map<String, dynamic>> _dailySetsCollectionForField(String fieldOfStudy) {
    final key = fieldOfStudy.toLowerCase().replaceAll(' ', '_');
    return _firestore.collection('daily_sets_$key');
  }

  Future<DailySet?> getDailySet(String fieldOfStudy, String dateId) async {
    final snapshot = await FirestoreErrors.guardFuture(
      _dailySetsCollectionForField(fieldOfStudy).doc(dateId).get(),
    );
    if (!snapshot.exists) return null;
    return DailySet.fromFirestore(snapshot);
  }

  Future<DailySet?> getLatestSetOnOrBefore(String fieldOfStudy, String dateId) async {
    final query = await FirestoreErrors.guardFuture(
      _dailySetsCollectionForField(fieldOfStudy)
          .where(FieldPath.documentId, isLessThanOrEqualTo: dateId)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get(),
    );
    if (query.docs.isEmpty) return null;
    return DailySet.fromFirestore(query.docs.first);
  }

  Future<List<Concept>> getConceptsByIds(String fieldOfStudy, List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final collection = _conceptsCollectionForField(fieldOfStudy);
    final allDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

    // Chunk by 10 for whereIn
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final query = await FirestoreErrors.guardFuture(
        collection.where(FieldPath.documentId, whereIn: chunk).get(),
      );
      allDocs.addAll(query.docs);
    }

    final conceptsMap = {
      for (final doc in allDocs) doc.id: Concept.fromFirestore(doc)
    };

    // Return in the order of ids, skip missing
    final result = <Concept>[];
    for (final id in ids) {
      if (conceptsMap.containsKey(id)) {
        result.add(conceptsMap[id]!);
      }
    }
    return result;
  }

  Future<TodaysConceptsResult> getTodaysConcepts(String fieldOfStudy, String dateId) async {
    DailySet? set = await getDailySet(fieldOfStudy, dateId);
    var isFallback = false;

    if (set == null) {
      set = await getLatestSetOnOrBefore(fieldOfStudy, dateId);
      isFallback = true;
    }

    if (set == null) {
      return const TodaysConceptsResult(isFallback: false);
    }

    final concepts = await getConceptsByIds(fieldOfStudy, set.conceptIds);
    return TodaysConceptsResult(
      dailySet: set,
      concepts: concepts,
      isFallback: isFallback,
    );
  }
}

