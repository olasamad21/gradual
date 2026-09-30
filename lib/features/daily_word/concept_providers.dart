import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/repositories/content_repository.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/field_utils.dart';

final todaysConceptsProvider = FutureProvider<TodaysConceptsResult>((ref) async {
  final user = ref.watch(
    appUserProvider.select(
      (asyncUser) => asyncUser.when(
        data: (d) => d,
        loading: () => null,
        error: (_, __) => null,
      ),
    ),
  );
  if (user == null) return const TodaysConceptsResult(isFallback: false);

  final contentRepo = ref.read(contentRepositoryProvider);
  final todayId = DateUtilsGradual.todayLocalDateId();
  
  try {
    return await contentRepo.getTodaysConcepts(
      effectiveField(user),
      todayId,
    );
  } catch (e, st) {
    throw FirestoreErrors.toAppException(e, st);
  }
});
