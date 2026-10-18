import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/concept_model.dart';
import '../../core/utils/field_utils.dart';
import '../quiz/quiz_providers.dart';
import 'saved_filter.dart';

final savedIdsProvider = Provider<List<String>>((ref) {
  final userAsync = ref.watch(appUserProvider);
  final user = userAsync.whenOrNull(data: (d) => d);
  if (user == null) return const [];
  return user.savedConceptIdsNewestFirst;
});

class SavedViewState {
  final String query;
  final String? category;
  final SavedSort sort;

  const SavedViewState({
    this.query = '',
    this.category,
    this.sort = SavedSort.newest,
  });

  SavedViewState copyWith({
    String? query,
    String? Function()? category,
    SavedSort? sort,
  }) {
    return SavedViewState(
      query: query ?? this.query,
      category: category != null ? category() : this.category,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedViewState &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          category == other.category &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(query, category, sort);
}

class SavedViewController extends Notifier<SavedViewState> {
  @override
  SavedViewState build() => const SavedViewState();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setCategory(String? category) {
    if (state.category == category) {
      state = state.copyWith(category: () => null);
    } else {
      state = state.copyWith(category: () => category);
    }
  }

  void setSort(SavedSort sort) {
    state = state.copyWith(sort: sort);
  }

  void reset() {
    state = const SavedViewState();
  }
}

final savedViewProvider =
    NotifierProvider<SavedViewController, SavedViewState>(
  SavedViewController.new,
);

class SavedController extends Notifier<void> {
  @override
  void build() {}

  int? toggle(String conceptId) {
    final userAsync = ref.read(appUserProvider);
    final user = userAsync.whenOrNull(data: (d) => d);
    if (user == null) return null;

    final previousMillis = user.savedConcepts[conceptId];
    final isCurrentlySaved = previousMillis != null;
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

    return isCurrentlySaved ? previousMillis : null;
  }

  Future<void> restore(String conceptId, int savedAtMillis) async {
    final userAsync = ref.read(appUserProvider);
    final user = userAsync.whenOrNull(data: (d) => d);
    if (user == null) return;

    try {
      await ref.read(userRepositoryProvider).setConceptSaved(
            uid: user.uid,
            conceptId: conceptId,
            saved: true,
            savedAtMillis: savedAtMillis,
          );
    } catch (_) {
      // Swallowed: Firestore stream reverts icon on failure.
    }
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
