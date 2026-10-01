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

enum QuizSaveResult { saved, alreadyTaken }
class CompletedQuizResult {
  const CompletedQuizResult({
    required this.sessionDateId,
    required this.score,
    required this.total,
    required this.tier,
    this.answers,
  });

  final String sessionDateId;
  final int score;
  final int total;
  final String tier;
  final List<QuizAnswer>? answers;
}
