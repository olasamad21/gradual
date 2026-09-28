import '../../core/models/weekly_quiz_model.dart';

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.sourceWord,
    required this.type,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String sourceWord;
  final String type; // mcq | true_false | fill_blank

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'source_word': sourceWord,
    'type': type,
  };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      options: List<String>.from(json['options'] as List? ?? []),
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
      sourceWord: json['source_word'] as String? ?? '',
      type: json['type'] as String? ?? 'mcq',
    );
  }
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

  Map<String, dynamic> toJson() => {
    'question': question.toJson(),
    'selectedIndex': selectedIndex,
  };

  factory QuizAnswer.fromJson(Map<String, dynamic> json) {
    return QuizAnswer(
      question: QuizQuestion.fromJson(
          json['question'] as Map<String, dynamic>),
      selectedIndex: (json['selectedIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Builds a flat list of questions for the UI from a WeeklyQuiz.
List<QuizQuestion> buildQuizFromWeekly(WeeklyQuiz quiz) {
  return quiz.questions.asMap().entries.map((entry) {
    final i = entry.key;
    final item = entry.value;
    final correctIndex = item.options.indexOf(item.answer);

    return QuizQuestion(
      id: '${quiz.weekEnd}-$i',
      text: item.question,
      options: item.options,
      correctIndex: correctIndex < 0 ? 0 : correctIndex,
      explanation: item.explanation,
      sourceWord: item.sourceWord,
      type: item.type,
    );
  }).toList();
}