import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/models/weekly_quiz_model.dart';
import '../streak/streak_providers.dart';
import 'quiz_models.dart';

final weeklyQuizProvider = FutureProvider<WeeklyQuiz?>((ref) async {
  final user = ref.watch(
    appUserProvider.select(
      (asyncUser) => asyncUser.when(
        data: (d) => d,
        loading: () => null,
        error: (_, __) => null,
      ),
    ),
  );
  if (user == null) return null;

  final contentRepo = ref.read(contentRepositoryProvider);
  final now = DateTime.now().toUtc();
  try {
    return await contentRepo.getWeeklyQuiz(
      fieldOfStudy: user.fieldOfStudy,
      date: now,
    );
  } catch (e, st) {
    throw FirestoreErrors.toAppException(e, st);
  }
});

class QuizState {
  const QuizState({
    required this.questions,
    required this.currentIndex,
    required this.correctCount,
    required this.completed,
  });

  final List<QuizQuestion> questions;
  final int currentIndex;
  final int correctCount;
  final bool completed;

  QuizQuestion? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  QuizState copyWith({
    List<QuizQuestion>? questions,
    int? currentIndex,
    int? correctCount,
    bool? completed,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      completed: completed ?? this.completed,
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
    );
  }

  Future<int> finalizeResults({
    required int correctCount,
    required int totalQuestions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final newStreak = await _userRepository.recordWeeklyQuiz(
      uid: user.uid,
      serverNow: DateTime.now().toUtc(),
      score: correctCount,
      totalQuestions: totalQuestions,
    );

    ref.invalidate(streakCountProvider);
    ref.invalidate(appUserProvider);
    return newStreak;
  }
}