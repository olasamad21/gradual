import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/concept_model.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_utils.dart';
import 'concept_providers.dart';
import '../streak/streak_providers.dart';

class TodayConceptsState {
  TodayConceptsState({
    required this.concepts,
    required this.readConceptIds,
    required this.isFallback,
    this.isWeekendReview = false,
    required this.userUid,
    required this.liveStreak,
  });

  final List<Concept> concepts;
  final Set<String> readConceptIds;
  final bool isFallback;
  final bool isWeekendReview;
  final String? userUid;
  final int liveStreak;

  int get readCount => readConceptIds.length;
  bool get isPerfectDay => concepts.isNotEmpty && readCount >= concepts.length;

  TodayConceptsState copyWith({
    List<Concept>? concepts,
    Set<String>? readConceptIds,
    bool? isFallback,
    bool? isWeekendReview,
    String? userUid,
    int? liveStreak,
  }) {
    return TodayConceptsState(
      concepts: concepts ?? this.concepts,
      readConceptIds: readConceptIds ?? this.readConceptIds,
      isFallback: isFallback ?? this.isFallback,
      isWeekendReview: isWeekendReview ?? this.isWeekendReview,
      userUid: userUid ?? this.userUid,
      liveStreak: liveStreak ?? this.liveStreak,
    );
  }
}

class TodayConceptsController extends AsyncNotifier<TodayConceptsState> {
  @override
  Future<TodayConceptsState> build() async {
    await ref.watch(statsResetProvider.future);
    final user = await ref.watch(appUserProvider.future);
    final conceptsResult = await ref.watch(todaysConceptsProvider.future);

    final todayId = DateUtilsGradual.todayLocalDateId();
    final today = DateUtilsGradual.dateFromId(todayId);
    final rawLog = user?.rawActivityLog ?? {};

    final Set<String> readIds;
    if (conceptsResult.isWeekendReview) {
      readIds = StreakEngine.conceptsReadInWeek(rawLog, today);
    } else {
      final todayLog = rawLog[todayId] as Map<String, dynamic>? ?? {};
      final rawRead = todayLog['concepts_read'] as List<dynamic>? ?? [];
      readIds = rawRead.map((e) => e.toString()).toSet();
    }

    return TodayConceptsState(
      concepts: conceptsResult.concepts,
      isFallback: conceptsResult.isFallback,
      isWeekendReview: conceptsResult.isWeekendReview,
      readConceptIds: readIds,
      userUid: user?.uid,
      liveStreak: user?.liveStreak ?? 0,
    );
  }

  Future<void> markRead(String conceptId) async {
    final previousState = state.whenOrNull(data: (d) => d);
    if (previousState == null) return;
    
    final previousReadIds = previousState.readConceptIds;
    if (previousReadIds.contains(conceptId)) return;

    final newReadIds = Set<String>.from(previousReadIds)..add(conceptId);
    state = AsyncData(previousState.copyWith(readConceptIds: newReadIds));

    final uid = previousState.userUid;
    if (uid == null) return; // Shouldn't happen if they are signed in

    try {
      final dateId = DateUtilsGradual.todayLocalDateId();
      await ref.read(userRepositoryProvider).recordConceptRead(
            uid: uid,
            conceptId: conceptId,
            dateId: dateId,
          );
      // Wait for the stream to emit the new data naturally, our optimistic state holds until then.
    } catch (e, st) {
      // Rollback
      state = AsyncData(previousState);
      state = AsyncError(e, st);
    }
  }
}

final todayConceptsControllerProvider =
    AsyncNotifierProvider<TodayConceptsController, TodayConceptsState>(
  TodayConceptsController.new,
);

/// Invalidates all providers in the chain that can hold a cached failure.
/// Does NOT invalidate appUserProvider.
void retryLoadConcepts(dynamic ref) {
  ref.invalidate(statsResetProvider);
  ref.invalidate(todaysConceptsProvider);
  ref.invalidate(todayConceptsControllerProvider);
}
