import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_rules.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_utils.dart';
import 'profile_quiz_stats.dart';

/// A rank earned by learning words. Each one needs more words than the last.
class LearnerLevel {
  const LearnerLevel({
    required this.number,
    required this.name,
    required this.minWords,
    this.nextMinWords,
  });

  final int number;
  final String name;
  final int minWords;

  /// Words needed for the next level, or null at the top level.
  final int? nextMinWords;

  /// 0 to 1 progress toward the next level.
  double progress(int words) {
    final next = nextMinWords;
    if (next == null) return 1;
    return ((words - minWords) / (next - minWords)).clamp(0.0, 1.0);
  }
}

const _levelSteps = [
  (0, 'Newcomer'),
  (10, 'Explorer'),
  (25, 'Builder'),
  (50, 'Engineer'),
  (100, 'Architect'),
  (200, 'Expert'),
];

LearnerLevel levelFor(int words) {
  var index = 0;
  for (var i = 0; i < _levelSteps.length; i++) {
    if (words >= _levelSteps[i].$1) index = i;
  }
  return LearnerLevel(
    number: index + 1,
    name: _levelSteps[index].$2,
    minWords: _levelSteps[index].$1,
    nextMinWords: index + 1 < _levelSteps.length ? _levelSteps[index + 1].$1 : null,
  );
}

/// Headline numbers for the Profile screen, all from the activity log.
class ProfileStats {
  const ProfileStats({
    required this.wordsLearned,
    required this.currentStreak,
    required this.bestStreak,
    required this.perfectDays,
    required this.quizzesTaken,
    required this.quizAccuracy,
    required this.hasExcellentQuiz,
    this.memberSince,
  });

  final int wordsLearned;
  final int currentStreak;
  final int bestStreak;
  final int perfectDays;
  final int quizzesTaken;

  /// 0 to 1, or null before the first quiz.
  final double? quizAccuracy;
  final bool hasExcellentQuiz;

  /// First day with any activity.
  final DateTime? memberSince;

  factory ProfileStats.from(AppUser user, DateTime today) {
    final log = user.rawActivityLog;
    final totals = quizStatsTotals(user);
    final datedKeys = log.keys.where((k) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(k)).toList()..sort();
    final perfect = StreakEngine.countedDays(log)
        .where((id) => StreakEngine.isPerfectDay(log, id, AppRules.conceptsPerDay))
        .length;
    final excellent = user.activityLog.values.any((e) =>
        e.isWeeklyQuiz &&
        (e.quizTier == 'excellent' ||
            ((e.quizTotal ?? 0) > 0 && StreakEngine.quizTier(e.quizScore ?? 0, e.quizTotal ?? 0) == 'excellent')));
    return ProfileStats(
      wordsLearned: StreakEngine.allConceptsRead(log).length,
      currentStreak: user.streakAt(today),
      bestStreak: StreakEngine.longestStreak(log),
      perfectDays: perfect,
      quizzesTaken: totalQuizzesDoneCount(user),
      quizAccuracy: totals.totalQuestions == 0 ? null : totals.totalCorrect / totals.totalQuestions,
      hasExcellentQuiz: excellent,
      memberSince: datedKeys.isEmpty ? null : DateUtilsGradual.dateFromId(datedKeys.first),
    );
  }
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int current;
  final int target;

  bool get unlocked => current >= target;
  double get progress => target == 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

List<Achievement> achievementsFor(ProfileStats s) => [
      Achievement(
        id: 'first-word',
        title: 'First step',
        description: 'Learn your first word',
        icon: Icons.flag_rounded,
        current: s.wordsLearned,
        target: 1,
      ),
      Achievement(
        id: 'perfect-day',
        title: 'Perfect day',
        description: 'Read all three words in a day',
        icon: Icons.star_rounded,
        current: s.perfectDays,
        target: 1,
      ),
      Achievement(
        id: 'streak-5',
        title: 'Full week',
        description: 'Keep a 5-day streak',
        icon: Icons.local_fire_department_rounded,
        current: s.bestStreak,
        target: 5,
      ),
      Achievement(
        id: 'words-25',
        title: 'Builder',
        description: 'Learn 25 words',
        icon: Icons.construction_rounded,
        current: s.wordsLearned,
        target: 25,
      ),
      Achievement(
        id: 'first-quiz',
        title: 'Quiz taker',
        description: 'Finish a weekly quiz',
        icon: Icons.quiz_rounded,
        current: s.quizzesTaken,
        target: 1,
      ),
      Achievement(
        id: 'quiz-ace',
        title: 'Top marks',
        description: 'Score Excellent on a quiz',
        icon: Icons.emoji_events_rounded,
        current: s.hasExcellentQuiz ? 1 : 0,
        target: 1,
      ),
      Achievement(
        id: 'streak-20',
        title: 'Month of focus',
        description: 'Keep a 20-day streak',
        icon: Icons.whatshot_rounded,
        current: s.bestStreak,
        target: 20,
      ),
      Achievement(
        id: 'words-100',
        title: 'Architect',
        description: 'Learn 100 words',
        icon: Icons.account_balance_rounded,
        current: s.wordsLearned,
        target: 100,
      ),
    ];

/// Words learned per category, most first. Fetches the read concepts once.
final learnedTopicsProvider = FutureProvider.autoDispose<List<(String, int)>>((ref) async {
  final user = ref.watch(appUserProvider).asData?.value;
  if (user == null) return const [];
  final ids = StreakEngine.allConceptsRead(user.rawActivityLog).toList();
  if (ids.isEmpty) return const [];
  final concepts = await ref.read(contentRepositoryProvider).getConceptsByIds(user.fieldOfStudy, ids);
  final counts = <String, int>{};
  for (final c in concepts) {
    if (c.category.trim().isEmpty) continue;
    counts[c.category] = (counts[c.category] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted) (e.key, e.value)];
});
