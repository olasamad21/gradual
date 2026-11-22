import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/streak_colors.dart';
import '../../core/utils/date_utils.dart';
import '../profile/profile_quiz_stats.dart';

/// Past weekly quiz results, newest first.
class QuizHistoryList extends StatelessWidget {
  const QuizHistoryList({super.key, required this.user, this.limit = 10});

  final AppUser user;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entries = sortedQuizHistoryEntries(user);
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 30, color: c.borderStrong),
            const SizedBox(height: 8),
            Text('Your quiz results will appear here.', style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length && i < limit; i++) ...[
            _HistoryRow(dateId: entries[i].key, entry: entries[i].value),
            if (i < entries.length - 1 && i < limit - 1)
              Divider(height: 1, thickness: 1, indent: 16, color: c.border.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.dateId, required this.entry});

  final String dateId;
  final ActivityLogEntry entry;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tier = entry.isWeeklyQuiz ? entry.tier : WeeklyScoreTier.legacy;
    final tierColor = StreakColors.tierColor(tier, c);
    final score = entry.quizScore ?? entry.score;
    final total = entry.quizTotal ?? entry.totalQuestions;
    final percent = total == 0 ? 0 : (score / total * 100).round();
    final date = DateUtilsGradual.dateFromId(dateId);
    final label = 'Week of ${date.day} ${_months[date.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 0 : score / total,
                  strokeWidth: 4,
                  backgroundColor: c.surfaceSunken,
                  color: tierColor,
                ),
                Text('$percent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('$score of $total correct', style: TextStyle(fontSize: 12, color: c.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tierColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
            child: Text(tier.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tierColor)),
          ),
        ],
      ),
    );
  }
}
