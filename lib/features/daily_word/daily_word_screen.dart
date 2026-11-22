import 'dart:async';
import '../../shared/widgets/dot_pattern.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_rules.dart';
import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../core/services/streak_engine.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/display_name.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../../shared/widgets/gradual_mark.dart';

import '../streak/day_reward_overlay.dart';
import '../streak/reward_tracker.dart';

import 'day_complete_card.dart';
import 'today_header.dart';
import 'word_card.dart';
import 'concept_reader.dart';
import 'today_concepts_controller.dart';
import 'read_aloud_controller.dart';
import '../quiz/quiz_providers.dart';
import '../saved/saved_controller.dart';
import '../../shared/widgets/app_shell.dart';
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
  bool isWeekendReview = false,
  required bool alreadyShown,
}) {
  if (isFallback || isWeekendReview) return false;
  if (alreadyShown) return false;
  if (reward != DayReward.perfect) return false;
  return newCount > previousCount;
}

class DailyWordScreen extends ConsumerStatefulWidget {
  const DailyWordScreen({super.key});

  @override
  ConsumerState<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends ConsumerState<DailyWordScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final Map<int, GlobalKey> _cardKeys = {};
  int _currentPage = 0;
  bool _initialPageSet = false;
  bool _isRetrying = false;
  Timer? _retryTimer;
  ReadAloudController? _readAloudNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFreshStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readAloudNotifier = ref.read(readAloudControllerProvider.notifier);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _readAloudNotifier?.stop();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _onRetry() {
    setState(() => _isRetrying = true);
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isRetrying) {
        setState(() => _isRetrying = false);
      }
    });
    retryLoadConcepts(ref);
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

    ref.listen<AsyncValue<TodayConceptsState>>(
      todayConceptsControllerProvider,
      (previous, next) {
        if (_isRetrying) {
          if (!next.hasError) {
            _retryTimer?.cancel();
            setState(() => _isRetrying = false);
          } else if (previous != null && (previous.isLoading || previous.isReloading) && !next.isLoading) {
            _retryTimer?.cancel();
            setState(() => _isRetrying = false);
          }
        }
      },
    );

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
        final isWeekendReview = conceptsState?.isWeekendReview ?? false;

        final reward = StreakEngine.dayReward(
          nextUser.rawActivityLog,
          todayId,
          AppRules.conceptsPerDay,
        );

        if (reward != DayReward.perfect) return;

        final tracker = RewardTracker();
        final shouldShow = await tracker.shouldShow(reward, todayId);

        final trigger = shouldTriggerReward(
          previousCount: prevCount,
          newCount: nextCount,
          reward: reward,
          isFallback: isFallback,
          isWeekendReview: isWeekendReview,
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
      error: (_, _) => null,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GradualMark(size: 26),
              const SizedBox(width: 8),
              Text(
                'Gradual',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: CustomPaint(
          painter: DotPatternPainter(color: context.colors.dotPattern),
          child: userAsync.hasError && FirestoreErrors.isPermissionDenied(userAsync.error)
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: FirestorePermissionWidget(),
                )
              : _buildBody(
                  context,
                  userAsync: userAsync,
                  conceptsAsync: conceptsAsync,
                  user: cachedUser,
                ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AsyncValue<AppUser?> userAsync,
    required AsyncValue<TodayConceptsState> conceptsAsync,
    required AppUser? user,
  }) {
    if (userAsync.isLoading && user == null) {
      return const _TodaySkeleton();
    }

    return conceptsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _TodaySkeleton(),
      error: (e, _) {
        if (FirestoreErrors.isPermissionDenied(e)) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: FirestorePermissionWidget(),
          );
        }
        return _buildLoadError(e);
      },
      data: (state) {
        final today = DateTime.now();
        final account = ref.watch(accountProfileProvider);
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: TodayHeader(
            greeting: _getGreeting(),
            firstName: firstNameFor(displayName: account.displayName, email: user?.email ?? ''),
            streak: user?.liveStreak ?? state.liveStreak,
            readCount: state.readCount,
            total: state.concepts.length,
            rawActivityLog: user?.rawActivityLog ?? const {},
            today: today,
            isWeekendReview: state.isWeekendReview,
          ),
        );

        if (state.concepts.isEmpty) {
          return Column(
            children: [
              header,
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty_rounded, size: 48, color: context.colors.borderStrong),
                      const SizedBox(height: 12),
                      Text(
                        'No concepts available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textMuted, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final allRead = state.isPerfectDay;
        final pageCount = state.concepts.length + (allRead ? 1 : 0);
        _setInitialPage(state);

        return Column(
          children: [
            header,
            const SizedBox(height: 18),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                clipBehavior: Clip.none,
                itemCount: pageCount,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  ref.read(readAloudControllerProvider.notifier).stop();
                },
                itemBuilder: (context, index) => _CarouselPage(
                  controller: _pageController,
                  index: index,
                  child: index == state.concepts.length
                      ? DayCompleteCard(
                          concepts: state.concepts,
                          streak: user?.liveStreak ?? state.liveStreak,
                          isWeekendReview: state.isWeekendReview,
                          onOpenWord: (i) => _openReader(state, i),
                          quizCta: _quizCta(),
                        )
                      : _buildWordCard(state, index),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PageDots(
              count: pageCount,
              current: _currentPage.clamp(0, pageCount - 1),
              readFlags: [for (final c in state.concepts) state.readConceptIds.contains(c.id)],
              hasCompletePage: allRead,
              onTap: (i) => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  /// Once data arrives, open on the completion card if the day is done.
  void _setInitialPage(TodayConceptsState state) {
    if (_initialPageSet) return;
    _initialPageSet = true;
    if (!state.isPerfectDay) return;
    final target = state.concepts.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(target);
      setState(() => _currentPage = target);
    });
  }

  VoidCallback? _quizCta() {
    final today = DateUtils.dateOnly(ref.read(todayProvider)());
    final quiz = ref.watch(quizButtonStateProvider(today));
    if (!quiz.isEnabled || quiz.isCompleted) return null;
    return () => ref.read(appShellTabProvider.notifier).state = 1;
  }

  Widget _buildWordCard(TodayConceptsState state, int index) {
    final concept = state.concepts[index];
    final key = _cardKeys.putIfAbsent(index, GlobalKey.new);
    final isSaved = ref.watch(savedIdsProvider).contains(concept.id);
    return KeyedSubtree(
      key: key,
      child: WordCard(
        concept: concept,
        index: index,
        total: state.concepts.length,
        isRead: state.readConceptIds.contains(concept.id),
        isSaved: isSaved,
        onOpen: () => _openReader(state, index, originKey: key),
        onToggleSaved: () {
          Haptics.light();
          ref.read(savedControllerProvider.notifier).toggle(concept.id);
        },
        onMarkRead: () => _markRead(state, index),
      ),
    );
  }

  void _markRead(TodayConceptsState state, int index) {
    final concept = state.concepts[index];
    if (state.readConceptIds.contains(concept.id)) return;
    Haptics.medium();
    ref.read(todayConceptsControllerProvider.notifier).markRead(concept.id);
    final target = nextPageAfterRead(
      readIds: {...state.readConceptIds, concept.id},
      conceptIds: [for (final c in state.concepts) c.id],
      index: index,
    );
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openReader(TodayConceptsState state, int index, {GlobalKey? originKey}) async {
    ref.read(readAloudControllerProvider.notifier).stop();
    Rect? origin;
    final box = originKey?.currentContext?.findRenderObject() as RenderBox?;
    final navBox = Navigator.of(context).context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && navBox != null) {
      origin = box.localToGlobal(Offset.zero, ancestor: navBox) & box.size;
    }
    final targetIndex = await openConceptReader(
      context: context,
      concepts: state.concepts,
      initialIndex: index,
      isWeekendReview: state.isWeekendReview,
      originRect: origin,
      onMarkRead: (conceptId) {
        ref.read(todayConceptsControllerProvider.notifier).markRead(conceptId);
      },
    );
    // Opened from a word card: land on the word the reader ended on.
    if (originKey != null && targetIndex != null && mounted && _pageController.hasClients && targetIndex != _currentPage) {
      _pageController.jumpToPage(targetIndex);
    }
  }

  Widget _buildLoadError(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: context.colors.borderStrong),
          const SizedBox(height: 12),
          Text(
            "Failed to load today's concepts.",
            style: TextStyle(color: context.colors.textMuted, fontSize: 15),
          ),
          if (FirestoreErrors.shouldRetry(e)) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isRetrying ? null : _onRetry,
              child: _isRetrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Page to move to after marking the word at [index] read: the completion
/// page when every word is read, else the next word if unread, else the
/// first unread word.
int nextPageAfterRead({
  required Set<String> readIds,
  required List<String> conceptIds,
  required int index,
}) {
  if (conceptIds.every(readIds.contains)) return conceptIds.length;
  final next = index + 1;
  if (next < conceptIds.length && !readIds.contains(conceptIds[next])) return next;
  return conceptIds.indexWhere((id) => !readIds.contains(id));
}

/// Scales and fades neighbouring pages so the current card stands out and
/// the next one peeks in from the side.
class _CarouselPage extends StatelessWidget {
  const _CarouselPage({required this.controller, required this.index, required this.child});

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: RepaintBoundary(child: child),
      ),
      builder: (context, child) {
        var page = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }
        final distance = (page - index).abs().clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 - distance * 0.06,
          child: Opacity(opacity: 1 - distance * 0.35, child: child),
        );
      },
    );
  }
}

/// Dots under the carousel: one per word (green once read) and a star for
/// the completion page. The current page is a wider pill.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.readFlags,
    required this.hasCompletePage,
    required this.onTap,
  });

  final int count;
  final int current;
  final List<bool> readFlags;
  final bool hasCompletePage;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            button: true,
            label: hasCompletePage && i == count - 1 ? 'Day summary' : 'Word ${i + 1}',
            selected: i == current,
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: hasCompletePage && i == count - 1
                    ? Icon(Icons.star_rounded, size: 16, color: i == current ? c.brand : c.borderStrong)
                    : AnimatedContainer(
                        duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: i == current ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: readFlags[i]
                              ? c.brand
                              : i == current
                                  ? c.textSecondary
                                  : c.borderStrong,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder shapes while today's words load.
class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.surfaceSunken;
    Widget block(double w, double h, [double r = 8]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(r)),
        );
    return Semantics(
      label: "Loading today's words",
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block(110, 14),
              const SizedBox(height: 8),
              block(160, 26),
              const SizedBox(height: 18),
              block(double.infinity, 112, 20),
              const SizedBox(height: 18),
              Expanded(child: block(double.infinity, double.infinity, 28)),
            ],
          ),
        ),
      ),
    );
  }
}
