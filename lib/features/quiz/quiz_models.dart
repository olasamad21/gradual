import '../../core/enums/difficulty_level.dart';
import '../../core/models/daily_content_model.dart';

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.isReview,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final DifficultyLevel difficulty;
  final bool isReview;
}

List<QuizQuestion> buildQuizFromContent(DailyContent content) {
  final questions = <QuizQuestion>[];

  for (final entry in content.quizzes.entries) {
    final level = entry.key;
    final quiz = entry.value;
    final correctIndex = quiz.options.indexOf(quiz.answer);

    questions.add(
      QuizQuestion(
        id: '${content.dateId}-${level.id}',
        text: quiz.question,
        options: quiz.options,
        correctIndex: correctIndex < 0 ? 0 : correctIndex,
        difficulty: level,
        isReview: false,
      ),
    );
  }

  return questions;
}

