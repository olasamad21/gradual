import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import 'review_controller.dart';
import 'review_session_screen.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Tomorrow", a weekday this week, or "12 Dec".
String friendlyDay(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff < 7) return _days[day.weekday - 1];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${day.day} ${months[day.month - 1]}';
}

/// Card that starts a review session: how many words are due, or when the
/// next one is. Hidden when nothing is in review at all.
class ReviewPrompt extends ConsumerWidget {
  const ReviewPrompt({super.key, this.subtitleWhenDue = 'Saved words and quiz misses, spaced out so they stick'});

  final String subtitleWhenDue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final summary = ref.watch(reviewSummaryProvider);
    if (summary.total == 0) return const SizedBox.shrink();
    final due = summary.due.length;
    final now = ref.read(reviewClockProvider)();
    final next = summary.nextDate;
    final hasDue = due > 0;

    return Semantics(
      button: hasDue,
      label: hasDue ? 'Review $due words' : 'All caught up',
      child: Material(
        color: hasDue ? c.accentPurple.withValues(alpha: 0.10) : c.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('review_prompt'),
          borderRadius: BorderRadius.circular(20),
          onTap: hasDue
              ? () {
                  Haptics.selection();
                  openReviewSession(context);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hasDue ? c.accentPurple.withValues(alpha: 0.35) : c.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.accentPurple.withValues(alpha: hasDue ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    hasDue ? Icons.psychology_rounded : Icons.check_circle_rounded,
                    color: c.accentPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDue ? (due == 1 ? '1 word to review' : '$due words to review') : 'Review all caught up',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasDue
                            ? subtitleWhenDue
                            : next == null
                                ? 'Nothing waiting right now'
                                : 'Next review ${friendlyDay(next, now)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (hasDue) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: c.accentPurple, borderRadius: BorderRadius.circular(999)),
                    child: Text('Start', style: TextStyle(fontWeight: FontWeight.w700, color: c.onBrand)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
