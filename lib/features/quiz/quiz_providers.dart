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

final todayProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final completedQuizResultProvider = FutureProvider.autoDispose<CompletedQuizResult?>((ref) async {
  final today = ref.watch(todayProvider)();
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return null;

  final sessionDateId = StreakEngine.quizDateIdInWeek(user.rawActivityLog, today);
  if (sessionDateId == null) return null;

  final entry = user.rawActivityLog[sessionDateId];
  if (entry is! Map) return null;

  final score = (entry['quiz_score'] is num) ? (entry['quiz_score'] as num).toInt() : 0;
  final total = (entry['quiz_total'] is num) ? (entry['quiz_total'] as num).toInt() : 0;
  
  final String tier;
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

  final status = StreakEngine.quizStatus(user.rawActivityLog, today);

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

class UnsavedQuizInfo {
  const UnsavedQuizInfo({this.sessionDateId, this.answers});
  final String? sessionDateId;
  final List<QuizAnswer>? answers;
  bool get hasUnsaved => sessionDateId != null && answers != null;
}

class UnsavedQuizResolver {
  const UnsavedQuizResolver(this.cache);
  final QuizResultCacheService cache;
  static final _dateIdPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  Future<UnsavedQuizInfo> resolve({
    required DateTime today,
    required Map<String, dynamic> activityLog,
  }) async {
    final ids = await cache.listPendingSessionIds();
    final currentWeek = StreakEngine.weekStartId(today);
    final isTaken = StreakEngine.quizTakenThisWeek(activityLog, today);

    String? bestId;

    for (final id in ids) {
      
      if (!_dateIdPattern.hasMatch(id)) {
        await cache.clearPending(id);
        continue;
      }
      final date = DateUtilsGradual.dateFromId(id);

      final week = StreakEngine.weekStartId(date);
      if (week != currentWeek || isTaken) {
        await cache.clearPending(id);
        continue;
      }

      final answers = await cache.loadPending(id);
      if (answers == null) {
        await cache.clearPending(id);
        continue;
      }

      if (bestId == null || id.compareTo(bestId) > 0) {
        bestId = id;
      }
    }

    if (bestId != null) {
      final answers = await cache.loadPending(bestId);
      if (answers != null) {
        return UnsavedQuizInfo(sessionDateId: bestId, answers: answers);
      }
    }
    return const UnsavedQuizInfo();
  }
}

final unsavedQuizProvider = FutureProvider.autoDispose<UnsavedQuizInfo>((ref) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return const UnsavedQuizInfo();

  final today = ref.read(todayProvider)();
  final cache = ref.read(quizResultCacheProvider);
  final resolver = UnsavedQuizResolver(cache);

  return resolver.resolve(today: today, activityLog: user.rawActivityLog);
});

class QuizSubmitOutcome {
  const QuizSubmitOutcome({required this.result, this.completed});
  final QuizSaveResult result;
  final CompletedQuizResult? completed;
}

class QuizSessionState {
  const QuizSessionState({
    required this.questions,
    required this.sessionDateId,
    required this.isSubmitting,
    this.score,
    this.total,
    this.answers = const [],
    this.submitFailed = false,
  });

  final List<QuizQuestion> questions;
  final String sessionDateId;
  final bool isSubmitting;
  final int? score;
  final int? total;
  final List<QuizAnswer> answers;
  final bool submitFailed;

  QuizSessionState copyWith({
    List<QuizQuestion>? questions,
    String? sessionDateId,
    bool? isSubmitting,
    int? score,
    int? total,
    List<QuizAnswer>? answers,
    bool? submitFailed,
  }) {
    return QuizSessionState(
      questions: questions ?? this.questions,
      sessionDateId: sessionDateId ?? this.sessionDateId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      score: score ?? this.score,
      total: total ?? this.total,
      answers: answers ?? this.answers,
      submitFailed: submitFailed ?? this.submitFailed,
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

      final log = user.rawActivityLog;
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

  Future<QuizSaveResult>? _runningSubmit;

  Future<QuizSubmitOutcome> retryPendingSave() async {
    try {
      final user = await ref.read(appUserProvider.future);
      if (user == null) return const QuizSubmitOutcome(result: QuizSaveResult.failed);

      final today = ref.read(todayProvider)();
      final cache = ref.read(quizResultCacheProvider);
      final resolver = UnsavedQuizResolver(cache);

      final info = await resolver.resolve(today: today, activityLog: user.rawActivityLog);
      if (!info.hasUnsaved) return const QuizSubmitOutcome(result: QuizSaveResult.failed);

      final result = await submitQuiz(
        today: today,
        answers: info.answers!,
        sessionDateId: info.sessionDateId,
      );

      if (result == QuizSaveResult.saved) {
        final score = info.answers!.where((a) => a.isCorrect).length;
        final total = info.answers!.length;
        final tier = StreakEngine.quizTier(score, total);
        return QuizSubmitOutcome(
          result: result,
          completed: CompletedQuizResult(
            sessionDateId: info.sessionDateId!,
            score: score,
            total: total,
            tier: tier,
            answers: info.answers!,
          ),
        );
      }
      return QuizSubmitOutcome(result: result);
    } catch (e) {
      return const QuizSubmitOutcome(result: QuizSaveResult.failed);
    }
  }

  Future<QuizSaveResult> submitQuiz({
    required DateTime today,
    required List<QuizAnswer> answers,
    String? sessionDateId,
  }) {
    if (_runningSubmit != null) return _runningSubmit!;
    _runningSubmit = _doSubmitQuiz(
      today: today,
      answers: answers,
      sessionDateId: sessionDateId,
    ).whenComplete(() {
      _runningSubmit = null;
    });
    return _runningSubmit!;
  }

  Future<QuizSaveResult> _doSubmitQuiz({
    required DateTime today,
    required List<QuizAnswer> answers,
    String? sessionDateId,
  }) async {
    final currentState = state.whenOrNull(data: (d) => d) ??
        const QuizSessionState(questions: [], sessionDateId: '', isSubmitting: false);

    final score = answers.where((a) => a.isCorrect).length;
    final total = answers.length;
    final tier = StreakEngine.quizTier(score, total);

    String id = sessionDateId ?? currentState.sessionDateId;
    if (id.isEmpty) id = DateUtilsGradual.localDateId(today);

    // a) set state: isSubmitting true, submitFailed false, answers set
    final submitting = currentState.copyWith(
      isSubmitting: true,
      submitFailed: false,
      answers: answers,
      score: score,
      total: total,
    );
    state = AsyncData(submitting);

    final cache = ref.read(quizResultCacheProvider);

    try {
      // b) await cache.savePending(id, answers) BEFORE any network call
      await cache.savePending(id, answers);

      // c) read the user. If there is no user, treat as failed.
      final user = await ref.read(appUserProvider.future);
      if (!ref.mounted) return QuizSaveResult.failed;
      if (user == null) {
        state = AsyncData(submitting.copyWith(
          isSubmitting: false,
          submitFailed: true,
        ));
        return QuizSaveResult.failed;
      }

      // d) call repository saveQuizScore
      final repo = ref.read(userRepositoryProvider);
      final result = await repo.saveQuizScore(
        uid: user.uid,
        dateId: id,
        score: score,
        total: total,
        tier: tier,
      );

      if (!ref.mounted) return result;

      if (result == QuizSaveResult.saved) {
        // e) saved
        await cache.saveAnswers(id, answers);
        await cache.clearPending(id);
        
        if (!ref.mounted) return result;
        
        state = AsyncData(submitting.copyWith(
          isSubmitting: false,
          submitFailed: false,
        ));
        ref.invalidate(appUserProvider);
        return QuizSaveResult.saved;
      } else if (result == QuizSaveResult.alreadyTaken) {
        // f) alreadyTaken
        await cache.clearPending(id);
        
        if (!ref.mounted) return result;
        
        state = AsyncData(submitting.copyWith(
          isSubmitting: false,
        ));
        ref.invalidate(appUserProvider);
        return QuizSaveResult.alreadyTaken;
      }

      return QuizSaveResult.failed;
    } catch (_) {
      // g) any exception or missing user: keep the pending answers on disk. 
      // State: isSubmitting false, submitFailed true, answers kept. Return failed.
      if (ref.mounted) {
        state = AsyncData(submitting.copyWith(
          isSubmitting: false,
          submitFailed: true,
        ));
      }
      return QuizSaveResult.failed;
    }
  }
}