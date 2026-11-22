import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_rules.dart';
import '../../core/models/user_model.dart';
import '../../core/services/streak_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradual_mark.dart';
import '../../shared/widgets/settings_group.dart';
import 'quiz_history.dart';

/// Time left until the quiz opens on Saturday at midnight, or null when it
/// is already the weekend.
Duration? timeUntilQuizOpens(DateTime now) {
  if (AppRules.quizWindowWeekdays.contains(now.weekday)) return null;
  final today = DateTime(now.year, now.month, now.day);
  final saturday = DateTime(today.year, today.month, today.day + (DateTime.saturday - now.weekday));
  return saturday.difference(now);
}

/// "2d 14h", "5h 20m" or "12m".
String formatCountdown(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes < 1 ? 1 : minutes}m';
}

/// The Quiz tab when no quiz is in progress: status, unlock progress, the
/// main action and past results.
class QuizHub extends StatefulWidget {
  const QuizHub({
    super.key,
    required this.user,
    required this.now,
    required this.status,
    required this.primaryLabel,
    required this.onPrimary,
    this.banner,
    this.practice,
  });

  final AppUser? user;
  final DateTime Function() now;
  final QuizStatus status;

  /// Main button text, or null when there is nothing to start.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Shown above the hero card, such as an unsaved-result notice.
  final Widget? banner;

  /// Practice any day: the spaced-review prompt.
  final Widget? practice;

  @override
  State<QuizHub> createState() => _QuizHubState();
}

class _QuizHubState extends State<QuizHub> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keep the countdown fresh while the tab is open.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = widget.now();
    final user = widget.user;
    final readThisWeek = user == null ? 0 : StreakEngine.conceptsReadInWeek(user.rawActivityLog, now).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Quiz', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Every weekend, test the words you learned that week.',
          style: TextStyle(fontSize: 14, color: c.textTertiary),
        ),
        const SizedBox(height: 20),
        if (widget.banner != null) ...[widget.banner!, const SizedBox(height: 16)],
        _HeroCard(
          status: widget.status,
          now: now,
          readThisWeek: readThisWeek,
          primaryLabel: widget.primaryLabel,
          onPrimary: widget.onPrimary,
        ),
        if (widget.practice != null) ...[
          const SizedBox(height: 28),
          const SectionLabel('Practice any day'),
          widget.practice!,
        ],
        const SizedBox(height: 24),
        const _HowItWorks(),
        const SizedBox(height: 28),
        const SectionLabel('Past results'),
        if (user != null) QuizHistoryList(user: user, limit: 8),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.status,
    required this.now,
    required this.readThisWeek,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final QuizStatus status;
  final DateTime now;
  final int readThisWeek;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final highlighted = status.type == QuizStatusType.available;
    final fg = highlighted ? Colors.white : c.textPrimary;
    final fgSoft = highlighted ? Colors.white.withValues(alpha: 0.85) : c.textTertiary;
    final need = AppRules.quizMinConceptsThisWeek;
    final countdown = timeUntilQuizOpens(now);

    final (pill, title, subtitle) = switch (status.type) {
      QuizStatusType.notYetOpen => (
          'OPENS SATURDAY',
          countdown == null ? 'Opens soon' : 'Opens in ${formatCountdown(countdown)}',
          readThisWeek >= need
              ? "You've read enough words to take it."
              : 'Read $need words this week to unlock it.',
        ),
      QuizStatusType.needMoreConcepts => (
          'ALMOST THERE',
          'Read ${status.conceptsNeeded} more ${status.conceptsNeeded == 1 ? 'word' : 'words'}',
          "The quiz unlocks once you've read $need words this week.",
        ),
      QuizStatusType.available => (
          'OPEN NOW',
          "This week's quiz",
          'One question for each word you read. About five minutes.',
        ),
      QuizStatusType.completed => (
          'DONE THIS WEEK',
          'Quiz complete',
          'A new quiz opens next Saturday.',
        ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: highlighted ? gradualIconGradient : null,
        color: highlighted ? null : c.surface,
        borderRadius: BorderRadius.circular(28),
        border: highlighted ? null : Border.all(color: c.border.withValues(alpha: 0.6)),
        boxShadow: highlighted
            ? [BoxShadow(color: c.brand.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 6))]
            : null,
      ),
      child: Stack(
        children: [
          if (highlighted)
            Positioned(
              right: -24,
              top: -16,
              child: Opacity(opacity: 0.14, child: GradualMark(size: 120, color: Colors.white)),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: highlighted ? Colors.white.withValues(alpha: 0.2) : c.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pill,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: highlighted ? Colors.white : c.brand,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: fg,
                    ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(fontSize: 14, height: 1.4, color: fgSoft)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Words read this week',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fgSoft),
                  ),
                  const Spacer(),
                  Text(
                    // Past the requirement, show it as met rather than "12 / 5".
                    readThisWeek >= need ? '$need / $need ✓' : '$readThisWeek / $need',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (readThisWeek / need).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: highlighted ? Colors.white.withValues(alpha: 0.25) : c.surfaceSunken,
                  color: highlighted ? Colors.white : c.brand,
                ),
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: highlighted ? Colors.white : c.inverseSurface,
                      foregroundColor: highlighted ? c.brandStrong : c.onInverseSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(primaryLabel!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(IconData icon, String text) => Expanded(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.3, color: c.textTertiary),
              ),
            ],
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(Icons.event_available_rounded, 'Opens Saturday and Sunday'),
        const SizedBox(width: 8),
        item(Icons.help_outline_rounded, 'One question per word you read'),
        const SizedBox(width: 8),
        item(Icons.grid_view_rounded, 'Your score colours the calendar'),
      ],
    );
  }
}
