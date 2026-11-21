import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../daily_word/concept_reader.dart';
import 'saved_controller.dart';
import 'saved_filter.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: ref.read(savedViewProvider).query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SavedViewState>(savedViewProvider, (previous, next) {
      if (next.query != _searchController.text) {
        _searchController.text = next.query;
      }
    });

    final savedIds = ref.watch(savedIdsProvider);
    if (savedIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
        ),
        body: _buildEmptyState(),
      );
    }

    final conceptsAsync = ref.watch(savedConceptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
      ),
      body: conceptsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: LoadingIndicator(label: 'Loading saved words...'),
        ),
        error: (error, stack) => _buildErrorState(),
        data: (concepts) {
          final conceptsMap = {for (final c in concepts) c.id: c};
          final allSavedConcepts = <Concept>[
            for (final id in savedIds)
              if (conceptsMap.containsKey(id)) conceptsMap[id]!,
          ];

          if (allSavedConcepts.isEmpty) {
            return _buildEmptyState();
          }

          final viewState = ref.watch(savedViewProvider);
          final categories = savedCategories(allSavedConcepts);
          final displayedConcepts = filterSavedConcepts(
            concepts: allSavedConcepts,
            query: viewState.query,
            category: viewState.category,
            sort: viewState.sort,
          );

          final isFilterActive =
              viewState.query.trim().isNotEmpty || viewState.category != null;
          final countText = isFilterActive
              ? '${displayedConcepts.length} of ${allSavedConcepts.length}'
              : '${allSavedConcepts.length} saved word${allSavedConcepts.length == 1 ? '' : 's'}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    onChanged: (val) {
                      ref.read(savedViewProvider.notifier).setQuery(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search saved words',
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      suffixIcon: viewState.query.isNotEmpty
                          ? SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: 'Clear search',
                                icon:
                                    const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(savedViewProvider.notifier)
                                      .setQuery('');
                                },
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: context.colors.surfaceSunken,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.colors.brand,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (categories.length > 1) ...[
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: viewState.category == null,
                        onSelected: (_) {
                          ref
                              .read(savedViewProvider.notifier)
                              .setCategory(null);
                        },
                      ),
                      for (final cat in categories) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(formatCategory(cat)),
                          selected: viewState.category == cat,
                          onSelected: (_) {
                            ref
                                .read(savedViewProvider.notifier)
                                .setCategory(cat);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        countText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                    PopupMenuButton<SavedSort>(
                      tooltip: 'Sort',
                      initialValue: viewState.sort,
                      onSelected: (sort) {
                        ref.read(savedViewProvider.notifier).setSort(sort);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: SavedSort.newest,
                          child: Text('Newest'),
                        ),
                        PopupMenuItem(
                          value: SavedSort.alphabetical,
                          child: Text('A to Z'),
                        ),
                      ],
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 48,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              viewState.sort == SavedSort.newest
                                  ? 'Newest'
                                  : 'A to Z',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textBody,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: context.colors.textBody,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (displayedConcepts.isEmpty)
                Expanded(
                  child: _buildNoResultsState(viewState),
                )
              else
                Expanded(
                  child: ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: displayedConcepts.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: context.colors.surfaceSunken,
                    ),
                    itemBuilder: (context, index) {
                      final concept = displayedConcepts[index];
                      return _buildSavedRow(
                        context,
                        concept,
                        displayedConcepts,
                        index,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved words yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark on any card to keep it here.',
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(SavedViewState viewState) {
    final message = viewState.query.trim().isNotEmpty
        ? 'No results for "${viewState.query.trim()}"'
        : 'Nothing saved in this topic';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(120, 48),
                foregroundColor: context.colors.brand,
              ),
              onPressed: () {
                ref.read(savedViewProvider.notifier).reset();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: context.colors.borderStrong,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load saved words.',
              style: TextStyle(
                fontSize: 15,
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: context.colors.brand,
                foregroundColor: context.colors.onBrand,
              ),
              onPressed: () => ref.invalidate(savedConceptsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedRow(
    BuildContext context,
    Concept concept,
    List<Concept> displayedConcepts,
    int index,
  ) {
    return InkWell(
      onTap: () {
        openConceptReader(
          context: context,
          concepts: displayedConcepts,
          initialIndex: index,
          showGotIt: false,
          onMarkRead: (_) {},
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    concept.term,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    concept.definition,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(
                  Icons.bookmark_rounded,
                  color: context.colors.brand,
                ),
                tooltip: 'Remove from saved',
                onPressed: () {
                  Haptics.light();
                  final previousMillis = ref
                      .read(savedControllerProvider.notifier)
                      .toggle(concept.id);
                  if (previousMillis != null && context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Removed from saved'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            ref
                                .read(savedControllerProvider.notifier)
                                .restore(concept.id, previousMillis);
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
