import 'package:flutter/material.dart';

import '../../core/models/concept_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradual_mark.dart';

/// Last page of the Today carousel once every word is read.
class DayCompleteCard extends StatelessWidget {
  const DayCompleteCard({
    super.key,
    required this.concepts,
    required this.streak,
    required this.isWeekendReview,
    required this.onOpenWord,
    this.quizCta,
  });

  final List<Concept> concepts;
  final int streak;
  final bool isWeekendReview;
  final void Function(int index) onOpenWord;

  /// Shown when this week's quiz is open; otherwise a "come back" note.
  final VoidCallback? quizCta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = isWeekendReview
        ? 'All caught up for this week!'
        : 'All done for today';
    final streakLine = streak == 1 ? '1 day streak' : '$streak day streak';
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    // Solid surface first, then a soft brand glow from the top.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.border.withValues(alpha: 0.7)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.brand.withValues(alpha: 0.12),
              c.brand.withValues(alpha: 0),
            ],
            stops: const [0, 0.6],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: disableAnimations ? 1 : 0.6, end: 1),
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: gradualIconGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: c.brand.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: c.caution,
                ),
                const SizedBox(width: 4),
                Text(
                  streakLine,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isWeekendReview ? 'YOU REVIEWED' : 'YOU LEARNED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < concepts.length; i++)
                        ActionChip(
                          label: Text(concepts[i].term),
                          avatar: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: c.brand,
                          ),
                          onPressed: () => onOpenWord(i),
                          backgroundColor: c.surfaceMuted,
                          side: BorderSide(color: c.border),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (quizCta != null)
              FilledButton.icon(
                onPressed: quizCta,
                icon: const Icon(Icons.quiz_rounded, size: 20),
                label: const Text("Take this week's quiz"),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: c.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    isWeekendReview
                        ? 'New words on Monday'
                        : 'New words tomorrow',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
