import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/daily_content_model.dart';

final todayContentProvider = FutureProvider<DailyContent?>((ref) async {
  final contentRepo = ref.watch(contentRepositoryProvider);
  final userAsync = ref.watch(appUserProvider);

  final user = userAsync.value;
  if (user == null) return null;

  final now = DateTime.now().toUtc();
  return contentRepo.getContentForDate(
    fieldOfStudy: user.fieldOfStudy,
    date: now,
  );
});

