import '../../core/models/review_item.dart';
import '../../core/models/user_model.dart';

/// Days until the next review after each correct answer in a row. Each
/// success roughly doubles the gap, the classic spaced-repetition curve.
const reviewIntervalsDays = [1, 3, 7, 14, 30, 60];

/// One word in the review queue, with why it is there.
class ReviewEntry {
  const ReviewEntry({
    required this.conceptId,
    required this.stage,
    required this.due,
    required this.fromSaved,
    required this.fromMissed,
  });

  final String conceptId;
  final int stage;
  final DateTime due;
  final bool fromSaved;
  final bool fromMissed;

  ReviewItem toItem() => ReviewItem(
        stage: stage,
        dueMillis: due.millisecondsSinceEpoch,
        fromSaved: fromSaved,
        fromMissed: fromMissed,
      );
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _daysAfter(DateTime from, int days) {
  final start = _startOfDay(from);
  return DateTime(start.year, start.month, start.day + days);
}

/// Every word in review. Saved words join on their own, due the day after
/// saving, without needing a stored item; stored items carry progress and
/// missed quiz words. A saved-only word that was unsaved drops out.
List<ReviewEntry> reviewQueue(AppUser user) {
  final entries = <String, ReviewEntry>{};

  for (final saved in user.savedConcepts.entries) {
    entries[saved.key] = ReviewEntry(
      conceptId: saved.key,
      stage: 0,
      due: _daysAfter(DateTime.fromMillisecondsSinceEpoch(saved.value), 1),
      fromSaved: true,
      fromMissed: false,
    );
  }

  for (final stored in user.reviewItems.entries) {
    final id = stored.key;
    final item = stored.value;
    final stillSaved = user.savedConcepts.containsKey(id);
    if (!item.fromMissed && !stillSaved) continue;
    entries[id] = ReviewEntry(
      conceptId: id,
      stage: item.stage,
      due: item.due,
      fromSaved: stillSaved,
      fromMissed: item.fromMissed,
    );
  }

  final list = entries.values.toList()
    ..sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      return byDue != 0 ? byDue : a.conceptId.compareTo(b.conceptId);
    });
  return list;
}

/// Words due today or earlier, oldest first.
List<ReviewEntry> dueReviews(AppUser user, DateTime now) {
  final endOfToday = _daysAfter(now, 1);
  return reviewQueue(user).where((e) => e.due.isBefore(endOfToday)).toList();
}

/// When the next not-yet-due word comes up, or null if nothing is waiting.
DateTime? nextReviewDate(AppUser user, DateTime now) {
  final endOfToday = _daysAfter(now, 1);
  for (final e in reviewQueue(user)) {
    if (!e.due.isBefore(endOfToday)) return e.due;
  }
  return null;
}

/// Progress after one review. Remembered moves to the next, longer gap;
/// forgotten goes back to the start and comes up again tomorrow.
ReviewItem afterReview(ReviewEntry entry, {required bool remembered, required DateTime now}) {
  if (!remembered) {
    return entry.toItem().copyWith(stage: 0, dueMillis: _daysAfter(now, 1).millisecondsSinceEpoch);
  }
  final next = entry.stage + 1;
  final gap = reviewIntervalsDays[next.clamp(0, reviewIntervalsDays.length - 1)];
  return entry.toItem().copyWith(stage: next, dueMillis: _daysAfter(now, gap).millisecondsSinceEpoch);
}

/// A word answered wrong in a quiz: back to the start, due tomorrow, and
/// kept in review even if it is not saved.
ReviewItem afterMissed(ReviewItem? existing, {required bool isSaved, required DateTime now}) => ReviewItem(
      stage: 0,
      dueMillis: _daysAfter(now, 1).millisecondsSinceEpoch,
      fromSaved: isSaved || (existing?.fromSaved ?? false),
      fromMissed: true,
    );
