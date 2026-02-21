import '../enums/difficulty_level.dart';

class QuizItem {
  QuizItem({
    required this.question,
    required this.options,
    required this.answer,
  });

  final String question;
  final List<String> options;
  final String answer;

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      answer: json['answer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      'options': options,
      'answer': answer,
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
  final Map<DifficultyLevel, QuizItem> quizzes;

  QuizItem? quizFor(DifficultyLevel level) => quizzes[level];

  factory DailyContent.fromJson(Map<String, dynamic> json) {
    final quizzes = <DifficultyLevel, QuizItem>{};
    final juniorRaw = json['quiz_junior'] as Map<String, dynamic>?;
    final seniorRaw = json['quiz_senior'] as Map<String, dynamic>?;
    final leadRaw = json['quiz_lead'] as Map<String, dynamic>?;

    if (juniorRaw != null) {
      quizzes[DifficultyLevel.junior] = QuizItem.fromJson(juniorRaw);
    }
    if (seniorRaw != null) {
      quizzes[DifficultyLevel.senior] = QuizItem.fromJson(seniorRaw);
    }
    if (leadRaw != null) {
      quizzes[DifficultyLevel.techLead] = QuizItem.fromJson(leadRaw);
    }

    return DailyContent(
      dateId: json['date_id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      analogy: json['analogy'] as String? ?? '',
      codeSnippet: json['code_snippet'] as String? ?? '',
      quizzes: quizzes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date_id': dateId,
      'word': word,
      'definition': definition,
      'analogy': analogy,
      'code_snippet': codeSnippet,
      'quiz_junior': quizzes[DifficultyLevel.junior]?.toJson(),
      'quiz_senior': quizzes[DifficultyLevel.senior]?.toJson(),
      'quiz_lead': quizzes[DifficultyLevel.techLead]?.toJson(),
    };
  }
}

