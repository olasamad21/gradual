import 'user_model.dart';
import '../enums/difficulty_level.dart';

export 'user_model.dart';

/// A single quiz question with options, correct answer, and explanation.
class QuizItem {
  QuizItem({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.type = 'mcq',
  });

  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String type; // mcq | true_false | fill_blank

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      type: json['type'] as String? ?? 'mcq',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      'options': options,
      'answer': answer,
      'explanation': explanation,
      'type': type,
    };
  }
}

class DailyContent {
  DailyContent({
    required this.dateId,
    required this.word,
    required this.definition,
    required this.analogy,
    required this.codeSnippet,
    required this.quizzes,
  });

  final String dateId;
  final String word;
  final String definition;
  final String analogy;
  final String codeSnippet;

  final Map<DifficultyLevel, List<QuizItem>> quizzes;

  List<QuizItem> questionsFor(DifficultyLevel level) =>
      quizzes[level] ?? const [];

  QuizItem? quizFor(DifficultyLevel level) {
    final list = quizzes[level];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }

  factory DailyContent.fromJson(Map<String, dynamic> json) {
    print('DEBUG dateId: ${json['date_id']}');
    print('DEBUG raw quiz_lead: ${json['quiz_lead']}');
    print('DEBUG quiz_lead type: ${json['quiz_lead']?.runtimeType}');

    return DailyContent(
      dateId: json['date_id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      analogy: json['analogy'] as String? ?? '',
      codeSnippet: json['code_snippet'] as String? ?? '',
      quizzes: {
        DifficultyLevel.junior:  _parseQuizArray(json['quiz_junior']),
        DifficultyLevel.senior:  _parseQuizArray(json['quiz_senior']),
        DifficultyLevel.techLead: _parseQuizArray(json['quiz_lead']),
      },
    );
  }

  static List<QuizItem> _parseQuizArray(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(QuizItem.fromJson)
          .toList();
    }

    if (raw is Map<String, dynamic>) {
      return [QuizItem.fromJson(raw)];
    }

    return const [];
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date_id': dateId,
      'word': word,
      'definition': definition,
      'analogy': analogy,
      'code_snippet': codeSnippet,
      'quiz_junior': quizzes[DifficultyLevel.junior]
          ?.map((q) => q.toJson())
          .toList() ?? [],
      'quiz_senior': quizzes[DifficultyLevel.senior]
          ?.map((q) => q.toJson())
          .toList() ?? [],
      'quiz_lead': quizzes[DifficultyLevel.techLead]
          ?.map((q) => q.toJson())
          .toList() ?? [],
    };
  }
}