import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/app_shell.dart';
import '../streak/streak_heatmap_widget.dart';
import '../streak/streak_success_modal.dart';
import '../quiz/quiz_result_cache_provider.dart';
import '../quiz/quiz_providers.dart';
import 'concept_card.dart';
import 'today_concepts_controller.dart';
import '../streak/streak_providers.dart';



class DailyWordScreen extends ConsumerStatefulWidget {
  const DailyWordScreen({super.key});

  @override
  ConsumerState<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends ConsumerState<DailyWordScreen> {
  @override
  void initState() {
    super.initState();
    _checkFreshStart();
  }

  Future<void> _checkFreshStart() async {
    // Wait for the reset migration to complete so the flag is set if needed.
    await ref.read(statsResetProvider.future);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('show_fresh_start_notice') == true) {
      await prefs.setBool('show_fresh_start_notice', false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Fresh Start', style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text('Streaks are now daily! Maintain your streak by marking at least 1 concept as read each day. A full set of 3 earns a perfect day star.', style: TextStyle(height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }





  @override
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final conceptsAsync = ref.watch(todayConceptsControllerProvider);
    
    ref.listen<AsyncValue<TodayConceptsState>>(
      todayConceptsControllerProvider,
      (previous, next) {
        final prevData = previous?.whenOrNull(data: (d) => d);
        final nextData = next.whenOrNull(data: (d) => d);
        
        if (prevData != null && nextData != null) {
          if (prevData.readCount == 0 && nextData.readCount == 1) {
            showDialog(
              context: context,
              builder: (ctx) => StreakSuccessModal(
                streakCount: nextData.liveStreak,
                
              ),
            );
          }
        }
      },
    );
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
                          conceptsAsync: conceptsAsync,
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
        rawActivityLog: cachedUser.rawActivityLog,
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
    required AsyncValue<TodayConceptsState> conceptsAsync,
    required AppUser? user,
  }) {
    if (userAsync.isLoading && user == null) {
      return const LoadingIndicator(label: "Loading today's concepts...");
    }

    return conceptsAsync.when(
      data: (state) {
        if (state.concepts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No concepts available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
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
                Expanded(
                  child: Text(
                    "${state.readCount} of ${state.concepts.length} today",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (state.isPerfectDay)
                  const Text(
                    "Perfect day!",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF388E3C),
                    ),
                  ),
              ],
            ),
            if (state.isFallback) ...[
              const SizedBox(height: 4),
              const Text(
                "Showing the latest available set",
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: state.concepts.length,
                itemBuilder: (context, index) {
                  final concept = state.concepts[index];
                  final isRead = state.readConceptIds.contains(concept.id);
                  return ConceptCard(
                    concept: concept,
                    isRead: isRead,
                    onMarkRead: () {
                      ref.read(todayConceptsControllerProvider.notifier).markRead(concept.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) {
                final quizState = ref.watch(quizButtonStateProvider(DateTime.now()));
                return PrimaryButton(
                  label: quizState.label,
                  onPressed: quizState.isEnabled
                      ? () {
                          ref.read(appShellTabProvider.notifier).state = 1;
                        }
                      : null,
                );
              },
            ),
            const SizedBox(height: 28),
          ],
        );
      },
      loading: () => const LoadingIndicator(label: "Loading today's concepts..."),
      error: (e, _) {
        if (FirestoreErrors.isPermissionDenied(e)) {
          return const FirestorePermissionWidget();
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Failed to load today\'s concepts.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              if (FirestoreErrors.shouldRetry(e)) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.invalidate(statsResetProvider);
                    ref.invalidate(todayConceptsControllerProvider);
                  },
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
      ..color = const Color(0xFFD1D5DB).withValues(alpha: 0.4)
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
