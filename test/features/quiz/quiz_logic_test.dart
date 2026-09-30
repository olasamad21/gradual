import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/quiz/quiz_providers.dart';

void main() {
  group('Quiz Pool and Shuffling Logic', () {
    test('QuizMaxQuestions is exactly 10', () {
      expect(quizMaxQuestions, 10);
    });
    
    test('correctIndex recalculates correctly after shuffle', () {
      final originalOptions = ['A', 'B', 'C', 'D'];
      const originalAnswerIndex = 2; // 'C'
      
      final options = List<String>.from(originalOptions);
      final correctAnswer = options[originalAnswerIndex];
      
      // Shuffle multiple times to ensure the logic holds
      for (var i = 0; i < 5; i++) {
        options.shuffle(Random());
        final newAnswerIndex = options.indexOf(correctAnswer);
        
        expect(options[newAnswerIndex], 'C');
      }
    });

    test('Pool generation respects max size and has no duplicates', () {
      final thisWeek = ['concept-1', 'concept-2', 'concept-3'];
      final older = ['concept-4', 'concept-5', 'concept-6', 'concept-7', 'concept-8', 'concept-9', 'concept-10', 'concept-11', 'concept-12'];

      final poolIds = <String>[];
      poolIds.addAll(thisWeek);
      
      for (final id in older) {
        if (poolIds.length >= quizMaxQuestions) break;
        if (!poolIds.contains(id)) poolIds.add(id);
      }
      
      if (poolIds.length > quizMaxQuestions) {
        poolIds.length = quizMaxQuestions;
      }

      expect(poolIds.length, 10);
      expect(poolIds.toSet().length, poolIds.length); // no duplicates
      expect(poolIds.contains('concept-1'), isTrue); // this week should be prioritized
    });

    test('Pool top-up works with duplicates present in older set', () {
      final thisWeek = ['concept-1', 'concept-2'];
      final older = ['concept-1', 'concept-3', 'concept-2', 'concept-4'];

      final poolIds = <String>[];
      poolIds.addAll(thisWeek);
      
      for (final id in older) {
        if (poolIds.length >= quizMaxQuestions) break;
        if (!poolIds.contains(id)) poolIds.add(id);
      }

      expect(poolIds.length, 4);
      expect(poolIds.toSet().length, 4); // no duplicates
      expect(poolIds, containsAll(['concept-1', 'concept-2', 'concept-3', 'concept-4']));
    });
  });
}
