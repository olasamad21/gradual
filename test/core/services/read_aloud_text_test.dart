import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/services/read_aloud_text.dart';

void main() {
  final fullConcept = Concept(
    id: 'test_id',
    term: ' State ',
    category: 'cat',
    level: 'lvl',
    definition: ' Definition ',
    analogy: ' Analogy ',
    realWorldExample: ' Example ',
    confusedWith: ' Confused-With ',
    related: [],
    quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
  );

  test('buildReadAloudSections order, skipping, prefixes and displayText', () {
    final sections = buildReadAloudSections(fullConcept);
    expect(sections.length, 5);
    
    expect(sections[0].kind, ReadSectionKind.term);
    expect(sections[0].displayText, 'State');
    expect(sections[0].spokenPrefix, '');

    expect(sections[1].kind, ReadSectionKind.definition);
    expect(sections[1].displayText, 'Definition');
    expect(sections[1].spokenPrefix, '');

    expect(sections[2].kind, ReadSectionKind.analogy);
    expect(sections[2].displayText, 'Analogy');
    expect(sections[2].spokenPrefix, 'Analogy. ');

    expect(sections[3].kind, ReadSectionKind.example);
    expect(sections[3].displayText, 'Example');
    expect(sections[3].spokenPrefix, 'Real world example. ');

    expect(sections[4].kind, ReadSectionKind.confusedWith);
    expect(sections[4].displayText, 'Confused With');
    expect(sections[4].spokenPrefix, 'Do not confuse with. ');

    final emptyConcept = Concept(
      id: 'test2',
      term: 'term',
      category: 'cat',
      level: 'lvl',
      definition: 'def',
      analogy: null,
      realWorldExample: '',
      confusedWith: '   ',
      related: [],
      quiz: const ConceptQuiz(question: '', options: [], answerIndex: 0, explanation: ''),
    );
    final emptySections = buildReadAloudSections(emptyConcept);
    expect(emptySections.length, 2);
  });

  test('wordRangeInDisplayed behaves correctly', () {
    // Normal range
    final res1 = wordRangeInDisplayed(prefixLength: 5, start: 5, end: 10, displayLength: 10);
    expect(res1?.start, 0);
    expect(res1?.end, 5);

    // Inside prefix
    final res2 = wordRangeInDisplayed(prefixLength: 5, start: 0, end: 4, displayLength: 10);
    expect(res2, isNull);

    // Past end
    final res3 = wordRangeInDisplayed(prefixLength: 5, start: 15, end: 20, displayLength: 10);
    expect(res3, isNull);

    // end <= start
    final res4 = wordRangeInDisplayed(prefixLength: 5, start: 10, end: 10, displayLength: 10);
    expect(res4, isNull);
  });
}
