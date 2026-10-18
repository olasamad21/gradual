import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/features/saved/saved_filter.dart';

void main() {
  Concept makeConcept({
    required String id,
    required String term,
    required String definition,
    required String category,
  }) {
    return Concept(
      id: id,
      term: term,
      category: category,
      definition: definition,
      level: 'beginner',
      analogy: null,
      realWorldExample: '',
      confusedWith: null,
      related: const [],
      quiz: const ConceptQuiz(
        question: '',
        options: [],
        answerIndex: 0,
        explanation: '',
      ),
    );
  }

  final c1 = makeConcept(
    id: 'c1',
    term: 'Banana',
    definition: 'A long yellow fruit.',
    category: 'fruits',
  );
  final c2 = makeConcept(
    id: 'c2',
    term: 'Apple',
    definition: 'A round fruit that grows on trees.',
    category: 'fruits',
  );
  final c3 = makeConcept(
    id: 'c3',
    term: 'Carrot',
    definition: 'An orange root vegetable.',
    category: 'vegetables',
  );
  final c4 = makeConcept(
    id: 'c4',
    term: 'apple',
    definition: 'Another duplicate lowercase term.',
    category: 'tech-gadgets',
  );

  group('saved_filter pure logic tests', () {
    test('empty query returns all in the same order', () {
      final input = [c1, c2, c3];
      final result = filterSavedConcepts(
        concepts: input,
        query: '',
        category: null,
        sort: SavedSort.newest,
      );
      expect(result, equals([c1, c2, c3]));
    });

    test('query matches term case-insensitively', () {
      final input = [c1, c2, c3];
      final result = filterSavedConcepts(
        concepts: input,
        query: 'apple',
        category: null,
        sort: SavedSort.newest,
      );
      expect(result, equals([c2]));
    });

    test('query matches definition case-insensitively', () {
      final input = [c1, c2, c3];
      final result = filterSavedConcepts(
        concepts: input,
        query: 'YELLOW',
        category: null,
        sort: SavedSort.newest,
      );
      expect(result, equals([c1]));
    });

    test('query matches formatted category case-insensitively', () {
      final input = [c1, c2, c3, c4];
      final result = filterSavedConcepts(
        concepts: input,
        query: 'Gadgets',
        category: null,
        sort: SavedSort.newest,
      );
      expect(result, equals([c4]));
    });

    test('no match returns empty', () {
      final input = [c1, c2, c3];
      final result = filterSavedConcepts(
        concepts: input,
        query: 'nonexistent keyword',
        category: null,
        sort: SavedSort.newest,
      );
      expect(result, isEmpty);
    });

    test('category filter works', () {
      final input = [c1, c2, c3, c4];
      final result = filterSavedConcepts(
        concepts: input,
        query: '',
        category: 'fruits',
        sort: SavedSort.newest,
      );
      expect(result, equals([c1, c2]));
    });

    test('query plus category combine', () {
      final input = [c1, c2, c3, c4];
      final result = filterSavedConcepts(
        concepts: input,
        query: 'round',
        category: 'fruits',
        sort: SavedSort.newest,
      );
      expect(result, equals([c2]));
    });

    test('alphabetical sort is case-insensitive with ties by id', () {
      final cTie1 = makeConcept(
        id: 'id-a',
        term: 'apple',
        definition: '',
        category: 'c',
      );
      final cTie2 = makeConcept(
        id: 'id-b',
        term: 'Apple',
        definition: '',
        category: 'c',
      );
      final cZ = makeConcept(
        id: 'id-z',
        term: 'Zebra',
        definition: '',
        category: 'c',
      );

      final input = [cZ, cTie2, cTie1];
      final result = filterSavedConcepts(
        concepts: input,
        query: '',
        category: null,
        sort: SavedSort.alphabetical,
      );
      expect(result, equals([cTie1, cTie2, cZ]));
    });

    test('the input list is not modified', () {
      final input = [c1, c2, c3];
      final originalOrder = List.of(input);
      filterSavedConcepts(
        concepts: input,
        query: 'apple',
        category: 'fruits',
        sort: SavedSort.alphabetical,
      );
      expect(input, equals(originalOrder));
    });

    test('savedCategories keeps first-appearance order and removes duplicates', () {
      final input = [c1, c2, c3, c4]; // fruits, fruits, vegetables, tech-gadgets
      final categories = savedCategories(input);
      expect(categories, equals(['fruits', 'vegetables', 'tech-gadgets']));
    });

    test('query with leading and trailing spaces is trimmed', () {
      final input = [c1, c2, c3];
      final result = filterSavedConcepts(
        concepts: input,
        query: '   banana   ',
        category: null,
        sort: SavedSort.newest,
      );
      expect(result, equals([c1]));
    });
  });

  group('formatCategory tests', () {
    test('formats hyphenated slugs to Title Case', () {
      expect(formatCategory('operating-systems'), 'Operating Systems');
    });

    test('formats underscored slugs to Title Case', () {
      expect(formatCategory('software_engineering'), 'Software Engineering');
    });

    test('formats single word and empty', () {
      expect(formatCategory('oop'), 'Oop');
      expect(formatCategory(''), '');
      expect(formatCategory('   '), '');
    });
  });
}
