import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/daily_content_model.dart';
import '../../core/utils/field_utils.dart';

final todayContentProvider = FutureProvider<DailyContent?>((ref) async {
  final user = ref.watch(
    appUserProvider.select(
      (asyncUser) => asyncUser.when(
        data: (d) => d,
        loading: () => null,
        error: (_, __) => null,
      ),
    ),
  );
  if (user == null) return null;

  final contentRepo = ref.read(contentRepositoryProvider);
  final now = DateTime.now().toUtc();
  try {
    return await contentRepo.getContentForDate(
      fieldOfStudy: effectiveField(user),
      date: now,
    );
  } catch (e, st) {
    throw FirestoreErrors.toAppException(e, st);
  }
});
