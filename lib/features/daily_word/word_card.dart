import 'package:flutter/material.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_colors.dart';
import '../saved/saved_filter.dart';

/// A word on the Today screen. Shows the term, a one-line summary and what
/// the reader holds. Tapping opens the full reader; "Got it" marks it read.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.concept,
    required this.index,
    required this.total,
    required this.isRead,
    required this.isSaved,
    required this.onOpen,
    required this.onMarkRead,
    required this.onToggleSaved,
  });

  final Concept concept;
  final int index;
  final int total;
  final bool isRead;
  final bool isSaved;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = c.wordAccent(index);
    final meta = [
      formatCategory(concept.category),
      formatCategory(concept.level),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Semantics(
      container: true,
      label:
          'Word ${index + 1} of $total: ${concept.term}${isRead ? ', read' : ''}',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: c.border.withValues(alpha: 0.7)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  accent.withValues(alpha: 0.10),
                  accent.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IndexBadge(index: index, isRead: isRead, accent: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          meta.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: accent,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: isSaved ? 'Remove from saved' : 'Save word',
                        onPressed: onToggleSaved,
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved ? c.brand : c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            concept.term,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontSize: 34,
                                  height: 1.08,
                                  letterSpacing: -0.8,
                                ),
                          ),
                          const SizedBox(height: 14),
                          // The summary gets all spare height; on very short
                          // screens it is clipped rather than overflowing.
                          Expanded(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  cardSummaryFor(concept),
                                  style: TextStyle(
                                    fontSize: 18,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: c.textBody,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InsideRow(concept: concept),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            onPressed: onOpen,
                            style: TextButton.styleFrom(
                              foregroundColor: c.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(48, 44),
                            ),
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Read more',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GotItButton(isRead: isRead, onPressed: onMarkRead),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({
    required this.index,
    required this.isRead,
    required this.accent,
  });

  final int index;
  final bool isRead;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = isRead ? context.colors.brand : accent;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: AnimatedSwitcher(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 300),
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: isRead
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('read'),
                size: 16,
                color: context.colors.onBrand,
              )
            : Center(
                key: const ValueKey('number'),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.colors.onBrand,
                  ),
                ),
              ),
      ),
    );
  }
}

class _GotItButton extends StatelessWidget {
  const _GotItButton({required this.isRead, required this.onPressed});

  final bool isRead;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
      child: isRead
          ? Container(
              key: const ValueKey('done'),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 18, color: c.brand),
                  const SizedBox(width: 6),
                  Text(
                    'Got it',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.brand,
                    ),
                  ),
                ],
              ),
            )
          : FilledButton(
              key: const ValueKey('todo'),
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                backgroundColor: c.inverseSurface,
                foregroundColor: c.onInverseSurface,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              child: const Text('Got it'),
            ),
    );
  }
}

/// Text for the card body: the concept's summary, or for older content the
/// first sentence of the definition, cut at a word boundary if it runs long.
String cardSummaryFor(Concept concept, {int maxChars = 120}) {
  final summary = concept.summary?.trim() ?? '';
  if (summary.isNotEmpty) return summary;
  final definition = concept.definition.trim();
  final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(definition);
  final first = (match?.group(0) ?? definition).trim();
  if (first.length <= maxChars) return first;
  final cut = first.substring(0, maxChars);
  final lastSpace = cut.lastIndexOf(' ');
  final clipped = (lastSpace > 40 ? cut.substring(0, lastSpace) : cut)
      .replaceAll(RegExp(r'[,;:\s]+$'), '');
  return '$clipped\u2026';
}

/// Small labels for what the reader holds beyond the summary.
class _InsideRow extends StatelessWidget {
  const _InsideRow({required this.concept});

  final Concept concept;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      if ((concept.analogy ?? '').trim().isNotEmpty)
        (Icons.lightbulb_outline_rounded, 'Analogy'),
      if (concept.realWorldExample.trim().isNotEmpty)
        (Icons.public_rounded, 'Example'),
      if ((concept.confusedWith ?? '').trim().isNotEmpty)
        (Icons.compare_arrows_rounded, 'Mix-ups'),
    ];
    final c = context.colors;
    return Semantics(
      label: 'Inside: ${items.map((e) => e.$2).join(', ')}',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (icon, label) in items)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                decoration: BoxDecoration(
                  color: c.surfaceSunken,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: c.textTertiary),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
