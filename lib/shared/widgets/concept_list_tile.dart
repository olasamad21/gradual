import 'package:flutter/material.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_style.dart';
import '../../features/daily_word/word_card.dart' show cardSummaryFor;
import '../../features/saved/saved_filter.dart';

/// A word as a card row: category tile, term, summary and topic line, with
/// an optional control on the right. Used by Saved and the word archive.
class ConceptListTile extends StatelessWidget {
  const ConceptListTile({super.key, required this.concept, required this.onTap, this.trailing});

  final Concept concept;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = categoryColor(c, concept.category);
    final meta = [
      formatCategory(concept.category),
      formatCategory(concept.level),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border.withValues(alpha: 0.6)),
          ),
          padding: EdgeInsets.fromLTRB(14, 12, trailing == null ? 14 : 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(categoryIcon(concept.category), size: 21, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      concept.term,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cardSummaryFor(concept),
                      style: TextStyle(fontSize: 13, height: 1.4, color: c.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
