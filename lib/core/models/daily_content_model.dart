import 'user_model.dart';
export 'user_model.dart';

class DailyContent {
  DailyContent({
    required this.dateId,
    required this.word,
    required this.definition,
    required this.analogy,
    required this.codeSnippet,
  });

  final String dateId;
  final String word;
  final String definition;
  final String analogy;
  final String codeSnippet;

  factory DailyContent.fromJson(Map<String, dynamic> json) {
    return DailyContent(
      dateId: json['date_id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      analogy: json['analogy'] as String? ?? '',
      codeSnippet: json['code_snippet'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date_id': dateId,
      'word': word,
      'definition': definition,
      'analogy': analogy,
      'code_snippet': codeSnippet,
    };
  }
}