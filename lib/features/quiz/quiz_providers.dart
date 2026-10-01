import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/field_utils.dart';
import 'quiz_models.dart';
import 'quiz_result_cache_provider.dart';

const int quizMaxQuestions = 10;
const int quizMinConcepts = 5; // Configured minimum to unlock quiz

final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final completedQuizResultProvider = FutureProvider.autoDispose<CompletedQuizResult?>((ref) async {
  final today = ref.watch(todayProvider);
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return null;

  final sessionDateId = StreakEngine.quizDateIdInWeek(user.rawActivityLog, today);
  if (sessionDateId == null) return null;

  final entry = user.rawActivityLog[sessionDateId];
  if (entry is! Map) return null;

  final score = (entry['quiz_score'] is num) ? (entry['quiz_score'] as num).toInt() : 0;
  final total = (entry['quiz_total'] is num) ? (entry['quiz_total'] as num).toInt() : 0;
  
  String tier = 'bronze';
  final rawTier = entry['quiz_tier'];
  if (rawTier is String && const ['excellent', 'good', 'fair', 'failed'].contains(rawTier)) {
    tier = rawTier;
  } else {
    tier = StreakEngine.quizTier(score, total);
  }

  final answers = await ref.read(quizResultCacheProvider).loadAnswers(sessionDateId);

  return CompletedQuizResult(
    sessionDateId: sessionDateId,
    score: score,
    total: total,
    tier: tier,
    answers: answers,
  );
});

class QuizButtonState {
  const QuizButtonState(this.label, this.isEnabled, this.isCompleted);
  final String label;
  final bool isEnabled;
  final bool isCompleted;
}

final quizButtonStateProvider = Provider.family<QuizButtonState, DateTime>((ref, today) {
  final userAsync = ref.watch(appUserProvider);
  final user = userAsync.whenOrNull(data: (d) => d);
  if (user == null) {
    return const QuizButtonState('Loading...', false, false);
  }

  final status = StreakEngine.quizStatus(user!.rawActivityLog, today);

  switch (status.type) {
    case QuizStatusType.notYetOpen:
      return const QuizButtonState('Quiz opens Saturday', false, false);
    case QuizStatusType.needMoreConcepts:
      final needed = status.conceptsNeeded;
      return QuizButtonState('Read $needed more concepts to unlock', false, false);
    case QuizStatusType.available:
      return const QuizButtonState('Take this week\'s quiz', true, false);
    case QuizStatusType.completed:
      return const QuizButtonState('View results', true, true);
  }
});

class QuizSessionState {
  const QuizSessionState({
    required this.questions,
    required this.sessionDateId,
    required this.isSubmitting,
    this.score,
    this.total,
  });

  final List<QuizQuestion> questions;
  final String sessionDateId;
  final bool isSubmitting;
  final int? score;
  final int? total;

  QuizSessionState copyWith({
    List<QuizQuestion>? questions,
    String? sessionDateId,
    bool? isSubmitting,
    int? score,
    int? total,
  }) {
    return QuizSessionState(
      questions: questions ?? this.questions,
      sessionDateId: sessionDateId ?? this.sessionDateId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      score: score ?? this.score,
      total: total ?? this.total,
    );
  }
}

final quizControllerProvider = AsyncNotifierProvider<QuizController, QuizSessionState>(
  QuizController.new,
);

class QuizController extends AsyncNotifier<QuizSessionState> {
  @override
  FutureOr<QuizSessionState> build() {
    return const QuizSessionState(
      questions: [],
      sessionDateId: '',
      isSubmitting: false,
    );
  }

  Future<void> generateQuiz(DateTime today) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(appUserProvider.future);
      if (user == null) throw Exception('User not logged in');

      final sessionDateId = DateUtilsGradual.localDateId(today);

      final log = user!.rawActivityLog;
      final weekStart = StreakEngine.weekStartId(today);

      final allRead = <String>{};
      final thisWeekRead = <String>{};

      log.forEach((dateId, entry) {
        if (entry is! Map<String, dynamic>) return;
        final concepts = entry['concepts_read'] as List<dynamic>? ?? [];
        for (final c in concepts) {
          final id = c.toString();
          allRead.add(id);
          if (dateId.compareTo(weekStart) >= 0 && dateId.compareTo(sessionDateId) <= 0) {
            thisWeekRead.add(id);
          }
        }
      });

      final older = allRead.difference(thisWeekRead).toList();
      final thisWeek = thisWeekRead.toList();

      final rand = Random();
      thisWeek.shuffle(rand);
      older.shuffle(rand);

      final poolIds = <String>[];
      poolIds.addAll(thisWeek);
      
      for (final id in older) {
        if (poolIds.length >= quizMaxQuestions) break;
        if (!poolIds.contains(id)) poolIds.add(id);
      }
      
      if (poolIds.length > quizMaxQuestions) {
        poolIds.length = quizMaxQuestions;
      }

      final contentRepo = ref.read(contentRepositoryProvider);
      final field = effectiveField(user);
      final concepts = await contentRepo.getConceptsByIds(field, poolIds);

      final questions = <QuizQuestion>[];
      for (final concept in concepts) {
        final q = concept.quiz;
        final options = List<String>.from(q.options);
        final correctAnswer = options[q.answerIndex];
        
        options.shuffle(rand);
        final newAnswerIndex = options.indexOf(correctAnswer);

        questions.add(QuizQuestion(
          id: concept.id,
          sourceWord: concept.term,
          text: q.question,
          type: 'mcq',
          options: options,
          correctIndex: newAnswerIndex,
          explanation: q.explanation,
        ));
      }

      state = AsyncData(QuizSessionState(
        questions: questions,
        sessionDateId: sessionDateId,
        isSubmitting: false,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<QuizSaveResult> submitQuiz(DateTime today, int score, int total) async {
    final currentState = state.whenOrNull(data: (d) => d);
    if (currentState == null || currentState.isSubmitting) return QuizSaveResult.saved;

    state = AsyncData(currentState.copyWith(isSubmitting: true));

    try {
      final user = await ref.read(appUserProvider.future);
      if (user == null) throw Exception('User not logged in');

      // Guard against double submit locally
      final status = StreakEngine.quizStatus(user.rawActivityLog, today);
      if (status.type == QuizStatusType.completed) {
        state = AsyncData(currentState.copyWith(
          isSubmitting: false,
          score: score,
          total: total,
        ));
        return QuizSaveResult.alreadyTaken;
      }

      double pct = total == 0 ? 0 : score / total;
      String tier = 'failed';
      if (pct >= 0.8) { tier = 'excellent'; }
      else if (pct >= 0.5) { tier = 'good'; }
      else if (pct >= 0.3) { tier = 'fair'; }

      final repo = ref.read(userRepositoryProvider);
      final result = await repo.saveQuizScore(
        uid: user.uid,
        dateId: currentState.sessionDateId,
        score: score,
        total: total,
        tier: tier,
      );

      if (result == QuizSaveResult.alreadyTaken) {
        state = AsyncData(currentState.copyWith(
          isSubmitting: false,
          score: score,
          total: total,
        ));
        return result;
      }

      // Invalidate user to refetch latest
      ref.invalidate(appUserProvider);

      state = AsyncData(currentState.copyWith(
        isSubmitting: false,
        score: score,
        total: total,
      ));
      
      return result;
    } catch (e, st) {
      state = AsyncData(currentState.copyWith(isSubmitting: false));
      state = AsyncError(e, st);
      rethrow;
    }
  }
}