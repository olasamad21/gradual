import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/repositories/content_repository.dart';
import '../../core/services/offline_content_cache.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/field_utils.dart';

final todaysConceptsProvider = FutureProvider<TodaysConceptsResult>((
  ref,
) async {
  final user = ref.watch(
    appUserProvider.select(
      (asyncUser) => asyncUser.when(
        data: (d) => d,
        loading: () => null,
        error: (_, _) => null,
      ),
    ),
  );
  if (user == null) return const TodaysConceptsResult(isFallback: false);

  final contentRepo = ref.read(contentRepositoryProvider);
  final cache = ref.read(offlineContentCacheProvider);
  final todayId = DateUtilsGradual.todayLocalDateId();

  try {
    final result = await contentRepo.getTodaysConcepts(
      effectiveField(user),
      todayId,
    );
    unawaited(cache.save(todayId, result));
    return result;
  } catch (e, st) {
    // No signal: fall back to the copy saved on the phone, if any.
    final saved = await cache.load(todayId);
    if (saved != null) return saved;
    throw FirestoreErrors.toAppException(e, st);
  }
});
