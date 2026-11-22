import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/concept_model.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/concept_list_tile.dart';
import '../daily_word/concept_reader.dart';
import '../saved/saved_controller.dart';
import '../saved/saved_filter.dart';
import 'archive_data.dart';

Future<void> openArchive(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ArchiveScreen()));
}

/// Every word the user has learned, newest week first, with search (FR-06).
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Concept c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.term.toLowerCase().contains(q) ||
        formatCategory(c.category).toLowerCase().contains(q) ||
        (c.summary ?? c.definition).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final archive = ref.watch(archiveProvider);
    final total = archive.asData?.value.fold<int>(0, (n, w) => n + w.concepts.length) ?? 0;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('All words'),
        bottom: total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      total == 1 ? '1 word learned' : '$total words learned',
                      style: TextStyle(fontSize: 13, color: c.textTertiary),
                    ),
                  ),
                ),
              ),
      ),
      body: archive.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Empty(
          icon: Icons.wifi_off_rounded,
          title: "Couldn't load your words",
          body: 'Check your connection and try again.',
          action: TextButton(onPressed: () => ref.invalidate(archiveProvider), child: const Text('Retry')),
        ),
        data: (weeks) {
          if (weeks.isEmpty) {
            return const _Empty(
              icon: Icons.auto_stories_rounded,
              title: 'Your library starts here',
              body: 'Every word you read is kept here, grouped by week.',
            );
          }
          final filtered = [
            for (final w in weeks)
              if (w.concepts.any(_matches)) ArchiveWeek(monday: w.monday, concepts: w.concepts.where(_matches).toList()),
          ];
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search all words',
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                      filled: true,
                      fillColor: c.surfaceSunken,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Empty(
                    icon: Icons.search_off_rounded,
                    title: 'No words match "${_query.trim()}"',
                    body: 'Try a different word or topic.',
                  ),
                ),
              for (final week in filtered) ..._weekSlivers(context, week, filtered),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _weekSlivers(BuildContext context, ArchiveWeek week, List<ArchiveWeek> all) {
    final c = context.colors;
    final topics = week.topics.join(' · ');
    final flat = [for (final w in all) ...w.concepts];
    final saved = ref.watch(savedIdsProvider);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      week.label.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: c.textMuted),
                    ),
                    if (topics.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(topics, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    ],
                  ],
                ),
              ),
              Text(
                week.concepts.length == 1 ? '1 word' : '${week.concepts.length} words',
                style: TextStyle(fontSize: 12, color: c.textTertiary),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: week.concepts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final concept = week.concepts[i];
            final isSaved = saved.contains(concept.id);
            return ConceptListTile(
              concept: concept,
              onTap: () => openConceptReader(
                context: context,
                concepts: flat,
                initialIndex: flat.indexOf(concept),
                showGotIt: false,
                onMarkRead: (_) {},
              ),
              trailing: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: isSaved ? 'Remove from saved' : 'Save word',
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? c.brand : c.textMuted,
                  ),
                  onPressed: () {
                    Haptics.light();
                    ref.read(savedControllerProvider.notifier).toggle(concept.id);
                  },
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: c.brand.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: c.brand),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: TextStyle(color: c.textTertiary, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
