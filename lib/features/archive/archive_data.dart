import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/concept_model.dart';
import '../../core/utils/date_utils.dart';
import '../saved/saved_filter.dart';

/// The date each word was first read, from the activity log.
Map<String, DateTime> firstReadDates(Map<String, dynamic> log) {
  final dates = log.keys.where((k) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(k)).toList()..sort();
  final first = <String, DateTime>{};
  for (final id in dates) {
    final entry = log[id];
    if (entry is! Map) continue;
    final read = entry['concepts_read'];
    if (read is! List) continue;
    for (final c in read.whereType<String>()) {
      first.putIfAbsent(c, () => DateUtilsGradual.dateFromId(id));
    }
  }
  return first;
}

/// Words learned in one week (Monday to Sunday).
class ArchiveWeek {
  const ArchiveWeek({required this.monday, required this.concepts});

  final DateTime monday;

  /// In the order they were read.
  final List<Concept> concepts;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "23 – 29 Nov" or "30 Nov – 6 Dec".
  String get label {
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    if (sunday.month == monday.month) {
      return '${monday.day} – ${sunday.day} ${_months[monday.month - 1]}';
    }
    return '${monday.day} ${_months[monday.month - 1]} – ${sunday.day} ${_months[sunday.month - 1]}';
  }

  /// The week's main topics, most common first.
  List<String> get topics {
    final counts = <String, int>{};
    for (final c in concepts) {
      if (c.category.trim().isEmpty) continue;
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(2)) formatCategory(e.key)];
  }
}

/// Groups words into weeks, newest week first.
List<ArchiveWeek> groupByWeek(List<Concept> concepts, Map<String, DateTime> firstRead) {
  final byWeek = <DateTime, List<(DateTime, Concept)>>{};
  for (final c in concepts) {
    final date = firstRead[c.id];
    if (date == null) continue;
    final monday = DateTime(date.year, date.month, date.day - (date.weekday - 1));
    byWeek.putIfAbsent(monday, () => []).add((date, c));
  }
  final weeks = byWeek.entries.map((e) {
    final items = e.value..sort((a, b) => a.$1.compareTo(b.$1));
    return ArchiveWeek(monday: e.key, concepts: [for (final i in items) i.$2]);
  }).toList()
    ..sort((a, b) => b.monday.compareTo(a.monday));
  return weeks;
}

/// Every word the user has read, grouped by week.
final archiveProvider = FutureProvider.autoDispose<List<ArchiveWeek>>((ref) async {
  final user = ref.watch(appUserProvider).asData?.value;
  if (user == null) return const [];
  final firstRead = firstReadDates(user.rawActivityLog);
  if (firstRead.isEmpty) return const [];
  final concepts = await ref.read(contentRepositoryProvider).getConceptsByIds(user.fieldOfStudy, firstRead.keys.toList());
  return groupByWeek(concepts, firstRead);
});
