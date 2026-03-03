import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/primary_button.dart';
import '../streak/streak_heatmap_widget.dart';
import '../quiz/quiz_result_cache_provider.dart';
import '../quiz/quiz_screen.dart';
import '../quiz/quiz_models.dart';
import 'daily_word_providers.dart';
import 'word_card.dart';

class DailyWordScreen extends ConsumerWidget {
  const DailyWordScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final contentAsync = ref.watch(todayContentProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text(
            'Gradual',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
              color: Color(0xFF1F2937),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline_rounded,
                  color: Color(0xFF374151)),
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: CustomPaint(
          painter: DotPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                userAsync.maybeWhen(
                  data: (user) {
                    final name = user?.email.split('@').first ?? 'Dev';
                    final greeting = _getGreeting();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280))),
                        const SizedBox(height: 2),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.5),
                            overflow: TextOverflow.ellipsis),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                userAsync.when(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return StreakHeatmapWidget(activityLog: user.activityLog);
                  },
                  loading: () =>
                  const SizedBox(height: 40, child: LoadingIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: contentAsync.when(
                    data: (content) {
                      if (content == null) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty_rounded,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No concept for today yet.',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15)),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF388E3C),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Today's Concept",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: WordCard(content: content)),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: 'Test Knowledge',
                            onPressed: () {
                              final user = userAsync.value;
                              // Read cache with correct type
                              final cache =
                              ref.read(quizResultCacheProvider);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => _LevelSelectorSheet(
                                  user: user,
                                  cache: cache,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    },
                    loading: () => const LoadingIndicator(
                        label: "Loading today's concept..."),
                    error: (_, __) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Failed to load today\'s concept.',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LEVEL SELECTOR SHEET
// ─────────────────────────────────────────────────────────────

class _LevelSelectorSheet extends StatelessWidget {
  const _LevelSelectorSheet({required this.user, required this.cache});
  final dynamic user;
  // Correctly typed to match quizResultCacheProvider
  final Map<String, List<QuizAnswer>> cache;

  static const _levels = [
    {
      'title': 'Junior',
      'subtitle': 'Check your understanding of the definition.',
      'difficulty': 'junior',
      'difficultyId': 'junior',
      'color': Color(0xFF22C55E),
      'icon': Icons.school_rounded,
    },
    {
      'title': 'Senior',
      'subtitle': 'Focus on syntax and application.',
      'difficulty': 'senior',
      'difficultyId': 'senior',
      'color': Color(0xFF3B82F6),
      'icon': Icons.code_rounded,
    },
    {
      'title': 'Tech Lead',
      'subtitle': 'System design and complex trade-offs.',
      'difficulty': 'tech_lead',
      'difficultyId': 'lead',
      'color': Color(0xFF8B5CF6),
      'icon': Icons.architecture_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 50 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FBF2),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Choose your level',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            const Text(
              'Each level tests different depths of understanding.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF), height: 1.4),
            ),
            const SizedBox(height: 20),
            ..._levels.asMap().entries.map((entry) {
              final level = entry.value;
              final index = entry.key;
              final difficultyId = level['difficultyId'] as String;
              final difficulty = level['difficulty'] as String;
              final isCompleted =
                  user?.hasCompletedToday(difficultyId) ?? false;

              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < _levels.length - 1 ? 10 : 0),
                child: TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 80)),
                  curve: Curves.easeOut,
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(24 * (1 - value), 0),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      if (isCompleted) {
                        // Use cache directly — no conversion needed
                        // since cache is already Map<String, List<QuizAnswer>>
                        final allAnswers =
                        Map<String, List<QuizAnswer>>.from(cache);
                        // Ensure this category exists in the map
                        allAnswers.putIfAbsent(difficultyId, () => []);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizResultScreen(
                              allAnswers: allAnswers,
                              initialDifficultyId: difficultyId,
                            ),
                          ),
                        );
                      } else {
                        Navigator.pushNamed(context, '/quiz',
                            arguments: difficulty);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFF9FAFB)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFFF3F4F6),
                        ),
                        boxShadow: isCompleted
                            ? []
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFFF3F4F6)
                                  : (level['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_rounded
                                  : (level['icon'] as IconData),
                              color: isCompleted
                                  ? const Color(0xFF9CA3AF)
                                  : (level['color'] as Color),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  level['title'] as String,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isCompleted
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isCompleted
                                      ? 'Already completed today · See result'
                                      : (level['subtitle'] as String),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isCompleted
                                ? Icons.visibility_rounded
                                : Icons.chevron_right_rounded,
                            color: isCompleted
                                ? const Color(0xFF9CA3AF)
                                : (level['color'] as Color).withOpacity(0.5),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB).withOpacity(0.4)
      ..strokeWidth = 1;
    const spacing = 24.0;
    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        canvas.drawCircle(Offset(i, j), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}