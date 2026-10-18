import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/concept_model.dart';
import '../../core/utils/field_utils.dart';
import '../quiz/quiz_providers.dart';

final savedIdsProvider = Provider<List<String>>((ref) {
  final userAsync = ref.watch(appUserProvider);
  final user = userAsync.whenOrNull(data: (d) => d);
  if (user == null) return const [];
  return user.savedConceptIdsNewestFirst;
});

class SavedController extends Notifier<void> {
  @override
  void build() {}

  void toggle(String conceptId) {
    final userAsync = ref.read(appUserProvider);
    final user = userAsync.whenOrNull(data: (d) => d);
    if (user == null) return;

    final isCurrentlySaved = user.savedConcepts.containsKey(conceptId);
    final nextSaved = !isCurrentlySaved;
    final savedAtMillis = ref.read(todayProvider)().millisecondsSinceEpoch;

    unawaited(() async {
      try {
        await ref.read(userRepositoryProvider).setConceptSaved(
              uid: user.uid,
              conceptId: conceptId,
              saved: nextSaved,
              savedAtMillis: savedAtMillis,
            );
      } catch (_) {
        // Swallowed: Firestore stream reverts icon on failure.
      }
    }());
  }
}

final savedControllerProvider =
    NotifierProvider<SavedController, void>(SavedController.new);

final savedConceptsProvider =
    FutureProvider.autoDispose<List<Concept>>((ref) async {
  final ids = ref.watch(savedIdsProvider);
  if (ids.isEmpty) return const [];

  final user = ref.read(appUserProvider).whenOrNull(data: (d) => d);
  final repo = ref.read(contentRepositoryProvider);
  return repo.getConceptsByIds(effectiveField(user), ids);
});
