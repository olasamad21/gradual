import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';

void main() {
  group('Concept Models', () {
    test('ConceptQuiz parses correctly', () {
      final json = {
        'question': 'Q?',
        'options': ['A', 'B', 'C', 'D'],
        'answer_index': 1,
        'explanation': 'Exp',
      };
      
      final quiz = ConceptQuiz.fromJson(json);
      expect(quiz.question, 'Q?');
      expect(quiz.options, ['A', 'B', 'C', 'D']);
      expect(quiz.answerIndex, 1);
      expect(quiz.explanation, 'Exp');
      
      final out = quiz.toJson();
      expect(out['answer_index'], 1);
    });

    test('Concept parses correctly with optionals', () {
      final json = {
        'id': 'test-1',
        'term': 'Test',
        'category': 'cat',
        'level': 'beginner',
        'definition': 'Def',
        'analogy': 'Analogy',
        'real_world_example': 'Example',
        'confused_with': 'Nothing',
        'related': ['test-2'],
        'quiz': {
          'question': 'Q?',
          'options': [],
          'answer_index': 0,
          'explanation': 'E'
        }
      };

      final concept = Concept.fromJson(json);
      expect(concept.id, 'test-1');
      expect(concept.analogy, 'Analogy');
      expect(concept.confusedWith, 'Nothing');
      expect(concept.quiz.question, 'Q?');
    });

    test('Concept parses safely with missing optionals', () {
      final json = {
        'id': 'test-1',
        'term': 'Test',
        'category': 'cat',
        'level': 'beginner',
        'definition': 'Def',
        'real_world_example': 'Example',
        'related': [],
        'quiz': {}
      };

      final concept = Concept.fromJson(json);
      expect(concept.analogy, isNull);
      expect(concept.confusedWith, isNull);
      expect(concept.quiz.question, '');
    });

    test('DailySet parses correctly', () {
      final json = {
        'date': '2026-10-05',
        'field': 'software_engineering',
        'theme': 'Theme',
        'concept_ids': ['1', '2', '3']
      };

      final ds = DailySet.fromJson(json);
      expect(ds.date, '2026-10-05');
      expect(ds.conceptIds.length, 3);
    });
  });
}
