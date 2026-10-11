import '../models/concept_model.dart';

enum ReadSectionKind { term, definition, analogy, example, confusedWith }

extension ReadSectionKindExt on ReadSectionKind {
  bool get onBackFace => this == ReadSectionKind.analogy || 
                         this == ReadSectionKind.example || 
                         this == ReadSectionKind.confusedWith;
}

class ReadSection {
  final ReadSectionKind kind;
  final String displayText;
  final String spokenPrefix;

  ReadSection({
    required this.kind,
    required this.displayText,
    required this.spokenPrefix,
  });
}

List<ReadSection> buildReadAloudSections(Concept concept) {
  final sections = <ReadSection>[];

  if (concept.term.trim().isNotEmpty) {
    sections.add(ReadSection(
      kind: ReadSectionKind.term,
      displayText: concept.term.trim(),
      spokenPrefix: '',
    ));
  }

  if (concept.definition.trim().isNotEmpty) {
    sections.add(ReadSection(
      kind: ReadSectionKind.definition,
      displayText: concept.definition.trim(),
      spokenPrefix: '',
    ));
  }

  if (concept.analogy != null && concept.analogy!.trim().isNotEmpty) {
    sections.add(ReadSection(
      kind: ReadSectionKind.analogy,
      displayText: concept.analogy!.trim(),
      spokenPrefix: 'Analogy. ',
    ));
  }

  if (concept.realWorldExample.trim().isNotEmpty) {
    sections.add(ReadSection(
      kind: ReadSectionKind.example,
      displayText: concept.realWorldExample.trim(),
      spokenPrefix: 'Real world example. ',
    ));
  }

  if (concept.confusedWith != null && concept.confusedWith!.trim().isNotEmpty) {
    var cw = concept.confusedWith!.trim();
    if (!cw.contains(' ') && cw.contains('-') && RegExp(r'^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)+$').hasMatch(cw)) {
      cw = cw.replaceAll('-', ' ');
    }
    sections.add(ReadSection(
      kind: ReadSectionKind.confusedWith,
      displayText: cw,
      spokenPrefix: 'Do not confuse with. ',
    ));
  }

  return sections;
}

String buildReadAloudText(Concept concept) {
  final sections = buildReadAloudSections(concept);
  return sections.map((s) => s.spokenPrefix + s.displayText).join(' ');
}

({int start, int end})? wordRangeInDisplayed({
  required int prefixLength,
  required int start,
  required int end,
  required int displayLength,
}) {
  final displayStart = start - prefixLength;
  final displayEnd = end - prefixLength;

  if (displayStart < 0 || displayEnd <= displayStart || displayEnd > displayLength) {
    return null;
  }

  return (start: displayStart, end: displayEnd);
}
