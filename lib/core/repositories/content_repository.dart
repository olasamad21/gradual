import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/firestore_errors.dart';
import '../models/concept_model.dart';

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

  CollectionReference<Map<String, dynamic>> _conceptsCollectionForField(String fieldOfStudy) {
    // For MVP, treat all users as software_engineering regardless of their saved preference
    return _firestore.collection('concepts_software_engineering');
  }

  CollectionReference<Map<String, dynamic>> _dailySetsCollectionForField(String fieldOfStudy) {
    // For MVP, treat all users as software_engineering regardless of their saved preference
    return _firestore.collection('daily_sets_software_engineering');
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
