import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/difficulty_level.dart';
import '../../core/firebase/firebase_providers.dart';
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
  late final UserRepository _userRepository;
  late final FirebaseAuth _auth;

  @override
  FutureOr<QuizState> build() {
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

  Future<void> finalizeResults({
    required DifficultyLevel difficulty,
    required int correctCount,
    required int totalQuestions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _userRepository.recordActivity(
      uid: user.uid,
      serverNow: DateTime.now().toUtc(),
      status: 'completed',
      difficulty: difficulty.id,
      score: correctCount,
      totalQuestions: totalQuestions,
    );

    ref.invalidate(streakCountProvider);
    ref.invalidate(appUserProvider);
  }
}