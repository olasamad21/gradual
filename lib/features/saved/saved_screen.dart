import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../daily_word/concept_reader.dart';
import 'saved_controller.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        error: (error, stack) => _buildErrorState(ref),
        data: (concepts) {
          final conceptsMap = {for (final c in concepts) c.id: c};
          final displayedConcepts = <Concept>[
            for (final id in savedIds)
              if (conceptsMap.containsKey(id)) conceptsMap[id]!,
          ];

          if (displayedConcepts.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: displayedConcepts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final concept = displayedConcepts[index];
              return _buildSavedCard(context, ref, concept, displayedConcepts, index);
            },
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
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No saved words yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark on any card to keep it here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load saved words.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF4B5563),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => ref.invalidate(savedConceptsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard(
    BuildContext context,
    WidgetRef ref,
    Concept concept,
    List<Concept> displayedConcepts,
    int index,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          openConceptReader(
            context: context,
            concepts: displayedConcepts,
            initialIndex: index,
            showGotIt: false,
            onMarkRead: (_) {},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            concept.term,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (concept.category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildTopicChip(concept.category),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      concept.definition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: const Icon(
                    Icons.bookmark_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  tooltip: 'Remove from saved',
                  onPressed: () {
                    ref.read(savedControllerProvider.notifier).toggle(concept.id);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicChip(String category) {
    final label = category.replaceAll('-', ' ').replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
