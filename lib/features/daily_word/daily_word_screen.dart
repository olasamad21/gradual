import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_rules.dart';
import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../../shared/widgets/loading_indicator.dart';

import '../streak/day_reward_overlay.dart';
import '../streak/reward_tracker.dart';
import '../streak/streak_heatmap_widget.dart';

import 'concept_flip_card.dart';
import 'today_concepts_controller.dart';
import 'read_aloud_controller.dart';
import '../streak/streak_providers.dart';

int _conceptCountForDate(Map<String, dynamic> log, String dateId) {
  final entry = log[dateId];
  if (entry is! Map) return 0;
  final concepts = entry['concepts_read'];
  if (concepts is! List) return 0;
  return concepts.whereType<String>().toSet().length;
}

bool shouldTriggerReward({
  required int previousCount,
  required int newCount,
  required DayReward reward,
  required bool isFallback,
  required bool alreadyShown,
}) {
  if (isFallback) return false;
  if (alreadyShown) return false;
  if (reward == DayReward.none) return false;
  return newCount > previousCount;
}

class DailyWordScreen extends ConsumerStatefulWidget {
  const DailyWordScreen({super.key});

  @override
  ConsumerState<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends ConsumerState<DailyWordScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFreshStart();
  }

  @override
  void dispose() {
    ref.read(readAloudControllerProvider.notifier).stop();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(readAloudControllerProvider.notifier).stop();
    }
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
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final conceptsAsync = ref.watch(todayConceptsControllerProvider);
    
    ref.listen<AsyncValue<AppUser?>>(
      appUserProvider,
      (previous, next) async {
        if (previous == null || previous.isLoading || !previous.hasValue || previous.value == null) {
          return;
        }
        if (next.isLoading || !next.hasValue || next.value == null) {
          return;
        }

        final prevUser = previous.value!;
        final nextUser = next.value!;

        final today = DateTime.now();
        final todayId = DateUtilsGradual.todayLocalDateId();

        final prevCount = _conceptCountForDate(prevUser.rawActivityLog, todayId);
        final nextCount = _conceptCountForDate(nextUser.rawActivityLog, todayId);

        if (nextCount <= prevCount) return;

        final conceptsState = ref.read(todayConceptsControllerProvider).asData?.value;
        final isFallback = conceptsState?.isFallback ?? false;

        final reward = StreakEngine.dayReward(
          nextUser.rawActivityLog,
          todayId,
          AppRules.conceptsPerDay,
        );

        final tracker = RewardTracker();
        final shouldShow = await tracker.shouldShow(reward, todayId);

        final trigger = shouldTriggerReward(
          previousCount: prevCount,
          newCount: nextCount,
          reward: reward,
          isFallback: isFallback,
          alreadyShown: !shouldShow,
        );

        if (!trigger) return;

        await tracker.markShown(reward, todayId);

        if (!mounted || !context.mounted) return;

        final streakCount = nextUser.streakAt(today);
        DayRewardOverlay.show(
          context,
          reward: reward,
          streakCount: streakCount,
        );
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
    
    final rawName = user?.email.split('@').first ?? 'Dev';
    final name = rawName.isNotEmpty ? '${rawName[0].toUpperCase()}${rawName.substring(1)}' : rawName;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text: '${_getGreeting()}, ',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
            letterSpacing: -0.5,
            
          ),
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(AsyncValue<AppUser?> userAsync, AppUser? cachedUser) {
    if (cachedUser != null) {
      return StreakHeatmapWidget(
        rawActivityLog: cachedUser.rawActivityLog,
        liveStreak: cachedUser.liveStreak,
        today: DateTime.now(),
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
      skipLoadingOnReload: true,
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
            Expanded(
              child: PageView.builder(
                clipBehavior: Clip.none,
                controller: _pageController,
                onPageChanged: (idx) {
                  ref.read(readAloudControllerProvider.notifier).stop();
                },
                itemCount: state.concepts.length,
                itemBuilder: (context, index) {
                  final concept = state.concepts[index];
                  final isRead = state.readConceptIds.contains(concept.id);
                  final readAloudState = ref.watch(readAloudControllerProvider);
                  final isReadingAloud = readAloudState.conceptId == concept.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 36, left: 4, right: 4, top: 4),
                    child: ConceptFlipCard(
                      concept: concept,
                      index: index,
                      isRead: isRead,
                      isLastWord: index == state.concepts.length - 1,
                      isReadingAloud: isReadingAloud,
                      readingSection: isReadingAloud ? readAloudState.section : null,
                      readingWordStart: isReadingAloud ? readAloudState.wordStart : null,
                      readingWordEnd: isReadingAloud ? readAloudState.wordEnd : null,
                      readingSpeed: isReadingAloud ? readAloudState.speed : 1.0,
                      onToggleReadAloud: () async {
                        final success = await ref.read(readAloudControllerProvider.notifier).toggle(concept);
                        if (!context.mounted) return;
                        if (!success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Read aloud isn't available on this device.")),
                          );
                        }
                      },
                      onCycleSpeed: () {
                        final currentSpeed = ref.read(readAloudControllerProvider).speed;
                        double nextSpeed = 1.0;
                        if (currentSpeed == 0.75) {
                          nextSpeed = 1.0;
                        } else if (currentSpeed == 1.0) {
                          nextSpeed = 1.25;
                        } else {
                          nextSpeed = 0.75;
                        }
                        ref.read(readAloudControllerProvider.notifier).setSpeed(nextSpeed);
                      },
                      onMarkRead: () {
                        ref.read(cardHintSeenProvider.notifier).markSeen();
                        ref.read(todayConceptsControllerProvider.notifier).markRead(concept.id);
                        
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted && _pageController.hasClients) {
                            if (index < state.concepts.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
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

