import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/daily_content_model.dart';
import '../../core/models/user_model.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/primary_button.dart';
import '../streak/streak_heatmap_widget.dart';
import '../quiz/quiz_result_cache_provider.dart';
import '../quiz/quiz_screen.dart';
import '../quiz/quiz_models.dart';
import 'daily_word_providers.dart';
import 'word_card.dart';

/// First date with imported content in Firestore (see content_json.json).
const _firstContentDateId = '2026-05-24';

class DailyWordScreen extends ConsumerWidget {
  const DailyWordScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _isSaturday => DateTime.now().weekday == DateTime.saturday;

  String _emptyConceptMessage() {
    final todayId =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    if (todayId.compareTo(_firstContentDateId) < 0) {
      return 'No concept for today yet.\nNew content starts on May 24, 2026.';
    }
    return 'No concept for today yet.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final contentAsync = ref.watch(todayContentProvider);
    final cachedUser = userAsync.when(
      data: (d) => d,
      loading: () => null,
      error: (_, __) => null,
    );

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
                _buildGreeting(userAsync),
                const SizedBox(height: 16),
                _buildHeatmap(userAsync, cachedUser),
                const SizedBox(height: 24),
                Expanded(
                  child: userAsync.hasError &&
                          FirestoreErrors.isPermissionDenied(userAsync.error)
                      ? const FirestorePermissionWidget()
                      : _buildConceptSection(
                          context,
                          ref,
                          userAsync: userAsync,
                          contentAsync: contentAsync,
                          user: cachedUser,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(AsyncValue<AppUser?> userAsync) {
    final user = userAsync.when(
      data: (d) => d,
      loading: () => null,
      error: (_, __) => null,
    );
    if (user == null && userAsync.isLoading) {
      return const SizedBox(height: 52);
    }
    final name = user?.email.split('@').first ?? 'Dev';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeatmap(AsyncValue<AppUser?> userAsync, AppUser? cachedUser) {
    if (cachedUser != null) {
      return StreakHeatmapWidget(
        activityLog: cachedUser.activityLog,
        liveStreak: cachedUser.liveStreak,
      );
    }
    if (userAsync.isLoading) {
      return const SizedBox(
        height: 40,
        child: LoadingIndicator(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildConceptSection(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<AppUser?> userAsync,
    required AsyncValue<DailyContent?> contentAsync,
    required AppUser? user,
  }) {
    if (userAsync.isLoading && user == null) {
      return const LoadingIndicator(label: "Loading today's concept...");
    }

    return contentAsync.when(
      data: (content) {
        if (content == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _emptyConceptMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 15,
                  ),
                ),
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
              label: _isSaturday
                  ? 'Take Weekly Quiz'
                  : 'Quiz Unlocks on Saturday',
              onPressed: _isSaturday
                  ? () {
                      final cache =
                          ref.read(quizResultCacheProvider).value ?? {};
                      final isCompleted = user?.hasCompletedThisWeek() ?? false;

                      if (isCompleted) {
                        final allAnswers =
                            Map<String, List<QuizAnswer>>.from(cache);
                        allAnswers.putIfAbsent('weekly', () => []);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizResultScreen(
                              allAnswers: allAnswers,
                              initialDifficultyId: 'weekly',
                            ),
                          ),
                        );
                      } else {
                        Navigator.pushNamed(context, '/quiz');
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 28),
          ],
        );
      },
      loading: () => const LoadingIndicator(
        label: "Loading today's concept...",
      ),
      error: (e, _) {
        if (FirestoreErrors.isPermissionDenied(e)) {
          return const FirestorePermissionWidget();
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Failed to load today\'s concept.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              if (FirestoreErrors.shouldRetry(e)) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(todayContentProvider),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        );
      },
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
