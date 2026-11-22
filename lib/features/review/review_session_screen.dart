import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/concept_model.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_style.dart';
import '../../shared/widgets/gradual_mark.dart';
import '../daily_word/concept_reader.dart';
import '../daily_word/word_card.dart' show cardSummaryFor;
import '../saved/saved_filter.dart';
import 'review_controller.dart';
import 'review_engine.dart';

Future<void> openReviewSession(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReviewSessionScreen()));
}

/// A run through every word due for review: a question per word, then a
/// summary of how it went and when the next review is.
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  int _index = 0;
  final Map<int, bool> _results = {};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = ref.watch(reviewSessionConceptsProvider);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Review'),
        actions: [
          if (session.asData?.value.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${math.min(_index + 1, session.asData!.value.length)} of ${session.asData!.value.length}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.textTertiary),
                ),
              ),
            ),
        ],
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(
          icon: Icons.wifi_off_rounded,
          title: "Couldn't load your review",
          body: 'Check your connection and try again.',
          action: 'Retry',
          onAction: () => ref.invalidate(reviewSessionConceptsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _Message(
              icon: Icons.check_circle_rounded,
              title: 'Nothing to review',
              body: 'Save words or take a weekly quiz, and they will come back here.',
              action: 'Done',
              onAction: () => Navigator.of(context).pop(),
            );
          }
          if (_index >= items.length) {
            return _SessionSummary(items: items, results: _results);
          }
          final (entry, concept) = items[_index];
          return Column(
            children: [
              _SegmentedProgress(total: items.length, index: _index, results: _results),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _ReviewCard(
                    key: ValueKey(entry.conceptId),
                    entry: entry,
                    concept: concept,
                    isLast: _index == items.length - 1,
                    onAnswered: (remembered) {
                      _results[_index] = remembered;
                      unawaited(ref.read(reviewControllerProvider).recordAnswer(entry, remembered: remembered));
                    },
                    onNext: () => setState(() => _index++),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.total, required this.index, required this.results});

  final int total;
  final int index;
  final Map<int, bool> results;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: results[i] == true
                      ? c.success
                      : results[i] == false
                          ? c.caution
                          : i == index
                              ? c.textSecondary
                              : c.surfaceSunken,
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

/// One word: its quiz question if it has one, else a reveal card.
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    super.key,
    required this.entry,
    required this.concept,
    required this.isLast,
    required this.onAnswered,
    required this.onNext,
  });

  final ReviewEntry entry;
  final Concept concept;
  final bool isLast;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late final List<String> _options;
  late final int _correct;
  int? _picked;
  bool _revealed = false;
  bool? _selfRated;

  bool get _hasQuiz {
    final q = widget.concept.quiz;
    return q.question.trim().isNotEmpty && q.options.length >= 2 && q.answerIndex >= 0 && q.answerIndex < q.options.length;
  }

  bool get _answered => _hasQuiz ? _picked != null : _selfRated != null;

  @override
  void initState() {
    super.initState();
    final q = widget.concept.quiz;
    if (_hasQuiz) {
      final answer = q.options[q.answerIndex];
      _options = List.of(q.options)..shuffle(math.Random(widget.concept.id.hashCode ^ DateTime.now().day));
      _correct = _options.indexOf(answer);
    } else {
      _options = const [];
      _correct = -1;
    }
  }

  void _pick(int i) {
    if (_picked != null) return;
    final right = i == _correct;
    right ? Haptics.light() : Haptics.medium();
    setState(() => _picked = i);
    widget.onAnswered(right);
  }

  void _rate(bool remembered) {
    if (_selfRated != null) return;
    Haptics.selection();
    setState(() => _selfRated = remembered);
    widget.onAnswered(remembered);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final concept = widget.concept;
    final accent = categoryColor(c, concept.category);
    final reason = widget.entry.fromMissed ? 'Missed in a quiz' : 'Saved';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
              child: Icon(categoryIcon(concept.category), size: 19, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                formatCategory(concept.category).toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: accent),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.entry.fromMissed ? Icons.refresh_rounded : Icons.bookmark_rounded,
                    size: 13,
                    color: c.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(reason, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textTertiary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          concept.term,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 30, height: 1.1, letterSpacing: -0.6),
        ),
        const SizedBox(height: 18),
        if (_hasQuiz) ..._quiz(context) else ..._reveal(context),
        if (_answered) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const ValueKey('review_next'),
              onPressed: widget.onNext,
              style: FilledButton.styleFrom(
                backgroundColor: c.inverseSurface,
                foregroundColor: c.onInverseSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(widget.isLast ? 'See results' : 'Next word'),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _quiz(BuildContext context) {
    final c = context.colors;
    final q = widget.concept.quiz;
    return [
      Text(q.question, style: TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w600, color: c.textPrimary)),
      const SizedBox(height: 16),
      for (var i = 0; i < _options.length; i++) _option(context, i),
      if (_picked != null) ...[
        const SizedBox(height: 6),
        _Explanation(
          right: _picked == _correct,
          text: q.explanation.trim().isNotEmpty ? q.explanation : cardSummaryFor(widget.concept),
          concept: widget.concept,
        ),
      ],
    ];
  }

  Widget _option(BuildContext context, int i) {
    final c = context.colors;
    final picked = _picked;
    final isCorrect = i == _correct;
    final isPicked = i == picked;
    Color border = c.border;
    Color fill = c.surface;
    Color badge = c.surfaceSunken;
    Color badgeText = c.textTertiary;
    if (picked != null && isCorrect) {
      border = c.success;
      fill = c.successSoft;
      badge = c.success;
      badgeText = c.onBrand;
    } else if (picked != null && isPicked) {
      border = c.dangerStrong;
      fill = c.dangerSoft;
      badge = c.dangerStrong;
      badgeText = c.onBrand;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: picked == null ? () => _pick(i) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.6),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(9)),
                  child: Center(
                    child: picked != null && (isCorrect || isPicked)
                        ? Icon(isCorrect ? Icons.check_rounded : Icons.close_rounded, size: 18, color: badgeText)
                        : Text(String.fromCharCode(65 + i),
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: badgeText)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_options[i], style: TextStyle(fontSize: 15, height: 1.35, color: c.textPrimary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _reveal(BuildContext context) {
    final c = context.colors;
    if (!_revealed) {
      return [
        Text('Can you explain it in your own words?', style: TextStyle(fontSize: 16, color: c.textTertiary)),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              Haptics.selection();
              setState(() => _revealed = true);
            },
            child: const Text('Show answer'),
          ),
        ),
      ];
    }
    return [
      Text(cardSummaryFor(widget.concept),
          style: TextStyle(fontSize: 18, height: 1.45, fontWeight: FontWeight.w500, color: c.textBody)),
      const SizedBox(height: 12),
      Text(widget.concept.definition, style: TextStyle(fontSize: 14, height: 1.55, color: c.textTertiary)),
      const SizedBox(height: 20),
      if (_selfRated == null)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(onPressed: () => _rate(false), child: const Text('Still learning')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(onPressed: () => _rate(true), child: const Text('I knew it')),
              ),
            ),
          ],
        ),
    ];
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.right, required this.text, required this.concept});

  final bool right;
  final String text;
  final Concept concept;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = right ? c.success : c.caution;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            right ? 'Nice, you remembered it' : "Not quite. It'll come back tomorrow",
            style: TextStyle(fontWeight: FontWeight.w700, color: tone),
          ),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: c.textBody)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openConceptReader(
                context: context,
                concepts: [concept],
                initialIndex: 0,
                showGotIt: false,
                onMarkRead: (_) {},
              ),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('Read the full word'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSummary extends ConsumerWidget {
  const _SessionSummary({required this.items, required this.results});

  final List<(ReviewEntry, Concept)> items;
  final Map<int, bool> results;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final remembered = results.values.where((r) => r).length;
    final now = ref.read(reviewClockProvider)();
    // The soonest any of these words returns.
    DateTime? next;
    for (var i = 0; i < items.length; i++) {
      final due = afterReview(items[i].$1, remembered: results[i] ?? false, now: now).due;
      if (next == null || due.isBefore(next)) next = due;
    }
    final nextLabel = next == null ? null : '${_days[next.weekday - 1]} ${next.day} ${_months[next.month - 1]}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: gradualIconGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: c.brand.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.psychology_rounded, size: 44, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Review done',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'You remembered $remembered of ${items.length}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: c.textTertiary),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                ListTile(
                  leading: Icon(
                    results[i] == true ? Icons.check_circle_rounded : Icons.replay_circle_filled_rounded,
                    color: results[i] == true ? c.success : c.caution,
                  ),
                  title: Text(items[i].$2.term, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    results[i] == true ? 'Back in ${_gapLabel(items[i].$1)}' : 'Back tomorrow',
                    style: TextStyle(color: c.textTertiary),
                  ),
                ),
            ],
          ),
        ),
        if (nextLabel != null) ...[
          const SizedBox(height: 16),
          Text(
            'Next review: $nextLabel',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textTertiary),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ),
      ],
    );
  }

  static String _gapLabel(ReviewEntry entry) {
    final next = (entry.stage + 1).clamp(0, reviewIntervalsDays.length - 1);
    final days = reviewIntervalsDays[next];
    return days == 1 ? '1 day' : '$days days';
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, required this.action, required this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: c.brand),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: TextStyle(color: c.textTertiary, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(width: 160, child: FilledButton(onPressed: onAction, child: Text(action))),
          ],
        ),
      ),
    );
  }
}
