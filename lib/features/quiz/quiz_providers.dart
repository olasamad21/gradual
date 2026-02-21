// lib/features/quiz/quiz_providers.dart

import 'dart:async'; // ADD THIS IMPORT
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/difficulty_level.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/repositories/content_repository.dart';
import '../../core/repositories/user_repository.dart';
import '../streak/streak_providers.dart';
import 'quiz_models.dart';

class QuizState {
  const QuizState({
    required this.questions,
    required this.currentIndex,
    required this.correctCount,
    required this.completed,
    required this.selectedDifficulty,
  });

  final List<QuizQuestion> questions;
  final int currentIndex;
  final int correctCount;
  final bool completed;
  final DifficultyLevel selectedDifficulty;

  QuizQuestion? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  QuizState copyWith({
    List<QuizQuestion>? questions,
    int? currentIndex,
    int? correctCount,
    bool? completed,
    DifficultyLevel? selectedDifficulty,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      completed: completed ?? this.completed,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
    );
  }
}

final quizControllerProvider =
AsyncNotifierProvider<QuizController, QuizState>(
  QuizController.new,
);

class QuizController extends AsyncNotifier<QuizState> {
  late final ContentRepository _contentRepository;
  late final UserRepository _userRepository;
  late final FirebaseAuth _auth;

  @override
  FutureOr<QuizState> build() {
    _contentRepository = ref.read(contentRepositoryProvider);
    _userRepository = ref.read(userRepositoryProvider);
    _auth = ref.read(firebaseAuthProvider);

    return const QuizState(
      questions: <QuizQuestion>[],
      currentIndex: 0,
      correctCount: 0,
      completed: false,
      selectedDifficulty: DifficultyLevel.junior,
    );
  }

  Future<void> startQuiz(DifficultyLevel difficulty) async {
    state = const AsyncLoading();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw StateError('User must be logged in');
      }

      final appUser = await _userRepository.getUser(user.uid);
      if (appUser == null) {
        throw StateError('User profile not found');
      }

      final todayContent = await _contentRepository.getContentForDate(
        fieldOfStudy: appUser.fieldOfStudy,
        date: DateTime.now().toUtc(),
      );

      if (todayContent == null) {
        throw StateError('No content for today');
      }

      final questions = buildQuizFromContent(todayContent).where(
            (q) => q.difficulty == difficulty,
      );

      final list = questions.toList();

      state = AsyncData(
        QuizState(
          questions: list,
          currentIndex: 0,
          correctCount: 0,
          completed: false,
          selectedDifficulty: difficulty,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void answer(int selectedIndex) {
    final current = state.value;
    if (current == null || current.completed) return;

    final question = current.currentQuestion;
    if (question == null) return;

    final isCorrect = selectedIndex == question.correctIndex;

    final nextCorrect = current.correctCount + (isCorrect ? 1 : 0);
    final nextIndex = current.currentIndex + 1;
    final completed = nextIndex >= current.questions.length;

    final nextState = current.copyWith(
      currentIndex: nextIndex,
      correctCount: nextCorrect,
      completed: completed,
    );

    state = AsyncData(nextState);
  }

  Future<void> finalizeResults() async {
    final current = state.value;
    if (current == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final selectedDifficulty = current.selectedDifficulty;
    final difficultyId = selectedDifficulty.id;

    await _userRepository.recordActivity(
      uid: user.uid,
      serverNow: DateTime.now().toUtc(),
      status: 'completed',
      difficulty: difficultyId,
      score: current.correctCount,
    );

    ref.invalidate(streakCountProvider);
    ref.invalidate(appUserProvider);
  }
}