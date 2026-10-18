import '../../core/models/concept_model.dart';

enum SavedSort {
  newest,
  alphabetical,
}

String formatCategory(String category) {
  if (category.trim().isEmpty) return '';
  return category
      .split(RegExp(r'[-_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

List<String> savedCategories(List<Concept> concepts) {
  final seen = <String>{};
  final result = <String>[];
  for (final c in concepts) {
    if (c.category.trim().isNotEmpty && seen.add(c.category)) {
      result.add(c.category);
    }
  }
  return result;
}

List<Concept> filterSavedConcepts({
  required List<Concept> concepts,
  required String query,
  required String? category,
  required SavedSort sort,
}) {
  final q = query.trim().toLowerCase();
  final filtered = concepts.where((c) {
    if (category != null && c.category != category) {
      return false;
    }
    if (q.isNotEmpty) {
      final termMatch = c.term.toLowerCase().contains(q);
      final defMatch = c.definition.toLowerCase().contains(q);
      final catMatch = formatCategory(c.category).toLowerCase().contains(q);
      if (!termMatch && !defMatch && !catMatch) {
        return false;
      }
    }
    return true;
  }).toList();

  if (sort == SavedSort.alphabetical) {
    filtered.sort((a, b) {
      final termComp = a.term.toLowerCase().compareTo(b.term.toLowerCase());
      if (termComp != 0) return termComp;
      return a.id.compareTo(b.id);
    });
  }

  return filtered;
}
