import 'package:cloud_firestore/cloud_firestore.dart';

class ConceptQuiz {
  const ConceptQuiz({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  factory ConceptQuiz.fromJson(Map<String, dynamic> json) {
    return ConceptQuiz(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      answerIndex: (json['answer_index'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'answer_index': answerIndex,
      'explanation': explanation,
    };
  }
}

class Concept {
  const Concept({
    required this.id,
    required this.term,
    required this.category,
    required this.level,
    required this.definition,
    this.analogy,
    required this.realWorldExample,
    this.confusedWith,
    required this.related,
    required this.quiz,
  });

  final String id;
  final String term;
  final String category;
  final String level;
  final String definition;
  final String? analogy;
  final String realWorldExample;
  final String? confusedWith;
  final List<String> related;
  final ConceptQuiz quiz;

  factory Concept.fromJson(Map<String, dynamic> json, [String? id]) {
    return Concept(
      id: id ?? json['id'] as String? ?? '',
      term: json['term'] as String? ?? '',
      category: json['category'] as String? ?? '',
      level: json['level'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      analogy: json['analogy'] as String?,
      realWorldExample: json['real_world_example'] as String? ?? '',
      confusedWith: json['confused_with'] as String?,
      related: (json['related'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      quiz: ConceptQuiz.fromJson(Map<String, dynamic>.from(json['quiz'] as Map? ?? {})),
    );
  }

  factory Concept.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Concept.fromJson(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'term': term,
      'category': category,
      'level': level,
      'definition': definition,
      if (analogy != null) 'analogy': analogy,
      'real_world_example': realWorldExample,
      if (confusedWith != null) 'confused_with': confusedWith,
      'related': related,
      'quiz': quiz.toJson(),
    };
  }
}

class DailySet {
  const DailySet({
    required this.date,
    required this.field,
    required this.theme,
    required this.conceptIds,
  });

  final String date;
  final String field;
  final String theme;
  final List<String> conceptIds;

  factory DailySet.fromJson(Map<String, dynamic> json) {
    return DailySet(
      date: json['date'] as String? ?? '',
      field: json['field'] as String? ?? '',
      theme: json['theme'] as String? ?? '',
      conceptIds: (json['concept_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  factory DailySet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DailySet.fromJson(doc.data() ?? {});
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'field': field,
      'theme': theme,
      'concept_ids': conceptIds,
    };
  }
}
