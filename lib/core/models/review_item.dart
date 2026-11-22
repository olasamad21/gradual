/// Spaced-review progress for one word, stored under `review_items` on the
/// user document.
class ReviewItem {
  const ReviewItem({
    required this.stage,
    required this.dueMillis,
    this.fromSaved = false,
    this.fromMissed = false,
  });

  /// How many times in a row it was remembered. Picks the next gap.
  final int stage;

  /// When it is next due, as milliseconds since epoch.
  final int dueMillis;

  /// Why it is in review: the user saved it, or missed it in a quiz.
  final bool fromSaved;
  final bool fromMissed;

  DateTime get due => DateTime.fromMillisecondsSinceEpoch(dueMillis);

  ReviewItem copyWith({int? stage, int? dueMillis, bool? fromSaved, bool? fromMissed}) => ReviewItem(
        stage: stage ?? this.stage,
        dueMillis: dueMillis ?? this.dueMillis,
        fromSaved: fromSaved ?? this.fromSaved,
        fromMissed: fromMissed ?? this.fromMissed,
      );

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'due': dueMillis,
        'saved': fromSaved,
        'missed': fromMissed,
      };

  /// Null for anything malformed, so one bad entry never breaks the rest.
  static ReviewItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final stage = json['stage'];
    final due = json['due'];
    if (stage is! num || due is! num) return null;
    return ReviewItem(
      stage: stage.toInt(),
      dueMillis: due.toInt(),
      fromSaved: json['saved'] == true,
      fromMissed: json['missed'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewItem &&
      other.stage == stage &&
      other.dueMillis == dueMillis &&
      other.fromSaved == fromSaved &&
      other.fromMissed == fromMissed;

  @override
  int get hashCode => Object.hash(stage, dueMillis, fromSaved, fromMissed);
}
