import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/concept_model.dart';
import '../../core/models/user_model.dart';
import 'review_engine.dart';

/// "Now" for review scheduling; tests pin it.
final reviewClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// What is waiting for review right now.
class ReviewSummary {
  const ReviewSummary({required this.due, required this.total, this.nextDate});

  /// Words due today or earlier, oldest first.
  final List<ReviewEntry> due;

  /// All words in review, due or not.
  final int total;

  /// When the next word comes up once today's are done.
  final DateTime? nextDate;

  static const empty = ReviewSummary(due: [], total: 0);
}

final reviewSummaryProvider = Provider<ReviewSummary>((ref) {
  final user = ref.watch(appUserProvider).asData?.value;
  if (user == null) return ReviewSummary.empty;
  final now = ref.watch(reviewClockProvider)();
  return ReviewSummary(
    due: dueReviews(user, now),
    total: reviewQueue(user).length,
    nextDate: nextReviewDate(user, now),
  );
});

/// Words to review in this session, with their content. Taken once when a
/// session opens, so answering doesn't reshuffle the deck mid-session.
final reviewSessionConceptsProvider = FutureProvider.autoDispose<List<(ReviewEntry, Concept)>>((ref) async {
  final user = ref.read(appUserProvider).asData?.value;
  if (user == null) return const [];
  final due = dueReviews(user, ref.read(reviewClockProvider)());
  if (due.isEmpty) return const [];
  final concepts = await ref.read(contentRepositoryProvider).getConceptsByIds(
        user.fieldOfStudy,
        [for (final e in due) e.conceptId],
      );
  final byId = {for (final c in concepts) c.id: c};
  return [
    for (final e in due)
      if (byId[e.conceptId] != null) (e, byId[e.conceptId]!),
  ];
});

/// Saves review results and missed quiz words to the user document.
class ReviewController {
  ReviewController(this.ref);

  final Ref ref;

  AppUser? get _user => ref.read(appUserProvider).asData?.value;

  /// Records one review answer and schedules the word's next review.
  Future<void> recordAnswer(ReviewEntry entry, {required bool remembered}) async {
    final user = _user;
    if (user == null) return;
    final item = afterReview(entry, remembered: remembered, now: ref.read(reviewClockProvider)());
    await ref.read(userRepositoryProvider).setReviewItem(
          uid: user.uid,
          conceptId: entry.conceptId,
          item: item.toJson(),
        );
  }

  /// Puts every word answered wrong in a weekly quiz into review tomorrow.
  Future<void> recordMissed(Iterable<String> conceptIds) async {
    final user = _user;
    if (user == null) return;
    final now = ref.read(reviewClockProvider)();
    final repo = ref.read(userRepositoryProvider);
    for (final id in conceptIds.toSet()) {
      if (id.isEmpty) continue;
      final item = afterMissed(
        user.reviewItems[id],
        isSaved: user.savedConcepts.containsKey(id),
        now: now,
      );
      try {
        await repo.setReviewItem(uid: user.uid, conceptId: id, item: item.toJson());
      } catch (_) {
        // Review is a bonus; a failed write must not affect the quiz result.
      }
    }
  }
}

final reviewControllerProvider = Provider<ReviewController>((ref) => ReviewController(ref));
