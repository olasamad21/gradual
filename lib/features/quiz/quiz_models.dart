import '../../core/enums/difficulty_level.dart';
import '../../core/models/daily_content_model.dart';

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.explanation,
    required this.type,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final DifficultyLevel difficulty;
  final String explanation;
  final String type; // mcq | true_false | fill_blank
}

/// Tracks a user's answer for a single question during a quiz session.
class QuizAnswer {
  QuizAnswer({
    required this.question,
    required this.selectedIndex,
  });

  final QuizQuestion question;
  final int selectedIndex;

  bool get isCorrect => selectedIndex == question.correctIndex;
}

/// Builds a flat list of questions for a given difficulty from DailyContent.
List<QuizQuestion> buildQuizFromContent(
    DailyContent content,
    DifficultyLevel difficulty,
    ) {
  final questions = content.questionsFor(difficulty);

  return questions.asMap().entries.map((entry) {
    final i = entry.key;
    final item = entry.value;
    final correctIndex = item.options.indexOf(item.answer);

    return QuizQuestion(
      id: '${content.dateId}-${difficulty.id}-$i',
      text: item.question,
      options: item.options,
      correctIndex: correctIndex < 0 ? 0 : correctIndex,
      difficulty: difficulty,
      explanation: item.explanation,
      type: item.type,
    );
  }).toList();
}