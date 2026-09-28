class WeeklyQuiz {
  WeeklyQuiz({
    required this.weekStart,
    required this.weekEnd,
    required this.questions,
  });

  final String weekStart;
  final String weekEnd;
  final List<QuizItem> questions;

  factory WeeklyQuiz.fromJson(Map<String, dynamic> json) {
    return WeeklyQuiz(
      weekStart: json['week_start'] as String? ?? '',
      weekEnd: json['week_end'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizItem.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'week_start': weekStart,
      'week_end': weekEnd,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

/// A single quiz question with options, correct answer, explanation, and source word.
class QuizItem {
  QuizItem({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.sourceWord,
    this.type = 'mcq',
  });

  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String sourceWord;
  final String type; // mcq | true_false | fill_blank

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      sourceWord: json['source_word'] as String? ?? '',
      type: json['type'] as String? ?? 'mcq',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      'options': options,
      'answer': answer,
      'explanation': explanation,
      'source_word': sourceWord,
      'type': type,
    };
  }
}
