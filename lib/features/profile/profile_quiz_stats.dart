import '../../core/models/user_model.dart';

class QuizStatsTotals {
  const QuizStatsTotals({
    required this.totalCorrect,
    required this.totalQuestions,
  });

  final int totalCorrect;
  final int totalQuestions;
}

/// Returns the number of completed weekly quizzes.
int totalQuizzesDoneCount(AppUser user) {
  return user.activityLog.values.where((e) => e.isWeeklyQuiz).length;
}

/// Returns the display string for total quizzes done (e.g. "2").
String totalQuizzesDone(AppUser user) {
  return '${totalQuizzesDoneCount(user)}';
}

/// Calculates the aggregate correct answers and total questions across all weekly quizzes.
QuizStatsTotals quizStatsTotals(AppUser user) {
  int totalCorrect = 0;
  int totalQuestions = 0;

  for (final entry in user.activityLog.values) {
    if (!entry.isWeeklyQuiz) continue;
    final score = entry.quizScore ?? entry.score;
    final total = entry.quizTotal ?? entry.totalQuestions;
    if (score < 0 || total <= 0) continue;
    totalCorrect += score;
    totalQuestions += total;
  }

  return QuizStatsTotals(
    totalCorrect: totalCorrect,
    totalQuestions: totalQuestions,
  );
}

/// Returns the overall percentage string (e.g. "80%") or "--" if no quizzes were taken.
String allTimeCorrectPercent(AppUser user) {
  final totals = quizStatsTotals(user);
  if (totals.totalQuestions == 0) return '--';
  return '${(totals.totalCorrect / totals.totalQuestions * 100).round()}%';
}

/// Returns all weekly quiz entries sorted newest first by date ID (YYYY-MM-DD).
List<MapEntry<String, ActivityLogEntry>> sortedQuizHistoryEntries(AppUser user) {
  final list = user.activityLog.entries
      .where((e) => e.value.isWeeklyQuiz)
      .toList();
  list.sort((a, b) => b.key.compareTo(a.key));
  return list;
}
