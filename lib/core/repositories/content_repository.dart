import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_content_model.dart';
import '../utils/date_utils.dart';

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

  Future<DailyContent?> getContentForDate({
    required String fieldOfStudy,
    required DateTime date,
  }) async {
    final dateId = DateUtilsGradual.toDateId(date);
    final snapshot =
        await _collectionForField(fieldOfStudy).doc(dateId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;

    data['date_id'] = dateId;

    return DailyContent.fromJson(data);
  }

  Future<List<DailyContent>> getHistory({
    required String fieldOfStudy,
    int limit = 30,
  }) async {
    final querySnapshot = await _collectionForField(fieldOfStudy)
        .orderBy('date_id', descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['date_id'] = doc.id;  // ← ADD THIS
      return DailyContent.fromJson(data);
    }).toList();
  }
}

