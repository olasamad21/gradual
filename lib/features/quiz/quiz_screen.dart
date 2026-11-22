import 'package:flutter/material.dart';
import '../../core/firebase/firebase_providers.dart';
import 'quiz_hub.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gradual/features/quiz/quiz_providers.dart';
import 'package:gradual/features/quiz/quiz_submit_failed_banner.dart';
import 'package:gradual/features/quiz/unsaved_quiz_card.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'quiz_models.dart';
import 'quiz_review_screen.dart';
import '../streak/quiz_result_box.dart';
import '../../shared/widgets/app_shell.dart';

// -----------------------------------------------------------------------------
// QUIZ SCREEN
// -----------------------------------------------------------------------------

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _sessionDate;
  int _currentIndex = 0;
  final Map<int, int> _selections = {};
  bool _hasStarted = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _selectOption(int index) {
    if (_selections[_currentIndex] != index) Haptics.selection();
    setState(() => _selections[_currentIndex] = index);
  }

  void _goNext(List<QuizQuestion> questions) {
    if (_currentIndex < questions.length - 1) {
      _slideController.reset();
      setState(() => _currentIndex++);
      _slideController.forward();
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      _slideController.reset();
      setState(() => _currentIndex--);
      _slideController.forward();
    }
  }

  Future<void> _submitQuiz(QuizSessionState state, {bool isRetry = false}) async {
    List<QuizAnswer> answers;
    if (isRetry) {
      answers = state.answers;
    } else {
      final questions = state.questions;
      answers = <QuizAnswer>[];
      for (var i = 0; i < questions.length; i++) {
        final selected = _selections[i] ?? 0;
        answers.add(QuizAnswer(
          question: questions[i],
          selectedIndex: selected,
        ));
      }
    }

    final correctCount = answers.where((a) => a.isCorrect).length;
    Haptics.medium();

    final result = await ref.read(quizControllerProvider.notifier).submitQuiz(
      today: _sessionDate!,
      answers: answers,
      sessionDateId: isRetry ? state.sessionDateId : null,
    );
    
    if (!mounted) return;

    if (result == QuizSaveResult.alreadyTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz already taken this week.')),
      );
      setState(() => _hasStarted = false);
      return;
    }

    if (result == QuizSaveResult.failed) {
      return;
    }

    setState(() {
      _hasStarted = false;
      _currentIndex = 0;
      _selections.clear();
    });

    final completedResult = CompletedQuizResult(
      sessionDateId: state.sessionDateId,
      score: correctCount,
      total: answers.length,
      tier: StreakEngine.quizTier(correctCount, answers.length),
      answers: answers,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(result: completedResult),
      ),
    );
  }


  Widget _buildStatusScreen(BuildContext context) {
    final today = ref.read(todayProvider)();
    final buttonState = ref.watch(quizButtonStateProvider(today));
    final unsavedInfo = ref.watch(unsavedQuizProvider).whenOrNull(data: (d) => d);
    final isSubmitting = ref.watch(quizControllerProvider).whenOrNull(data: (d) => d)?.isSubmitting ?? false;
    final user = ref.watch(appUserProvider).asData?.value;
    final status = user == null
        ? const QuizStatus(QuizStatusType.notYetOpen)
        : StreakEngine.quizStatus(user.rawActivityLog, today);
    final hasUnsaved = unsavedInfo != null && unsavedInfo.hasUnsaved;
    final showPrimary = buttonState.isEnabled && !(hasUnsaved && !buttonState.isCompleted);

    Future<void> onPrimary() async {
      if (buttonState.isCompleted) {
        final result = await ref.read(completedQuizResultProvider.future);
        if (!context.mounted) return;
        if (result != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuizResultScreen(result: result)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't load your results. Please try again.")),
          );
        }
        return;
      }
      Haptics.medium();
      setState(() {
        _hasStarted = true;
        _sessionDate = ref.read(todayProvider)();
      });
      ref.read(quizControllerProvider.notifier).generateQuiz(_sessionDate!);
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: QuizHub(
          user: user,
          now: ref.read(todayProvider),
          status: status,
          primaryLabel: showPrimary ? (buttonState.isCompleted ? 'View Results' : 'Start Quiz') : null,
          onPrimary: showPrimary ? onPrimary : null,
          banner: hasUnsaved
              ? UnsavedQuizCard(
                  isSaving: isSubmitting,
                  onRetry: () async {
                    final outcome = await ref.read(quizControllerProvider.notifier).retryPendingSave();
                    if (!context.mounted) return;
                    ref.invalidate(unsavedQuizProvider);
                    if (outcome.result == QuizSaveResult.saved && outcome.completed != null) {
                      setState(() {
                        _hasStarted = false;
                        _currentIndex = 0;
                        _selections.clear();
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizResultScreen(result: outcome.completed!),
                        ),
                      );
                    } else if (outcome.result == QuizSaveResult.alreadyTaken) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quiz already taken this week.')),
                      );
                    } else if (outcome.result == QuizSaveResult.failed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't save your score. Check your connection and retry.")),
                      );
                    }
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStarted) {
      return _buildStatusScreen(context);
    }

    final sessionAsync = ref.watch(quizControllerProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: sessionAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.brand),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessionState) {
          if (sessionState.questions.isEmpty) {
            return const Center(child: Text('No quiz available.'));
          }

          final displayQuestions = sessionState.questions;
          final safeIndex = _currentIndex.clamp(0, displayQuestions.length - 1);
          final question = displayQuestions[safeIndex];
          final selectedIndex = _selections[safeIndex];
          final isLast = safeIndex == displayQuestions.length - 1;
          final allAnswered = _selections.length == displayQuestions.length;

          return PopScope(
            canPop: !sessionState.isSubmitting,
            child: SafeArea(
              child: KeyedSubtree(
child: Column(
                children: [
                  _buildHeader(context, displayQuestions.length, isSubmitting: sessionState.isSubmitting),
                  _buildProgressBar(displayQuestions.length),
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuestionCard(question),
                            const SizedBox(height: 20),
                            ...question.options.asMap().entries.map(
                                  (e) => _buildOptionTile(
                                index: e.key,
                                text: e.value,
                                selectedIndex: selectedIndex,
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (sessionState.submitFailed)
                    QuizSubmitFailedBanner(
                      isSaving: sessionState.isSubmitting,
                      onRetry: () => _submitQuiz(sessionState, isRetry: true),
                    ),
                  _buildBottomBar(
                    isLast: isLast,
                    allAnswered: allAnswered,
                    selectedIndex: selectedIndex,
                    isSubmitting: sessionState.isSubmitting,
                    onNext: () => _goNext(displayQuestions),
                    onSubmit: () => _submitQuiz(sessionState),
                  ),
                ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int total, {required bool isSubmitting}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: context.colors.textPrimary),
            onPressed: isSubmitting ? null : () => ref.read(appShellTabProvider.notifier).state = 0,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Quiz',
              style: TextStyle(
                color: context.colors.brand,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_currentIndex + 1} / $total',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int total) {
    final progress = total == 0 ? 0.0 : ((_currentIndex + 1) / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: context.colors.border,
          valueColor: AlwaysStoppedAnimation<Color>(context.colors.brand),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.surfaceSunken,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'MULTIPLE CHOICE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            question.text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required int index,
    required String text,
    required int? selectedIndex,
  }) {
    final isSelected = selectedIndex == index;
    final optionLetter = String.fromCharCode(65 + index);

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.brand.withValues(alpha: 0.05)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? context.colors.brand
                : context.colors.border,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.brand
                    : context.colors.surfaceSunken,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  optionLetter,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isSelected ? context.colors.onBrand : context.colors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textBody,
                  height: 1.4,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: context.colors.brand, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required bool isLast,
    required bool allAnswered,
    required int? selectedIndex,
    required bool isSubmitting,
    required VoidCallback onNext,
    required VoidCallback onSubmit,
  }) {
    final bool canSubmit = isLast && allAnswered && !isSubmitting;
    final bool canGoNext = !isLast && selectedIndex != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: context.colors.background,
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentIndex > 0)
            GestureDetector(
              onTap: _goPrevious,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border, width: 2),
                ),
                child: Icon(Icons.arrow_back_rounded, color: context.colors.textBody),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: canSubmit
                    ? onSubmit
                    : canGoNext
                    ? onNext
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit
                      ? context.colors.wordAccents[0]
                      : context.colors.brand,
                  disabledBackgroundColor: context.colors.borderStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isSubmitting
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: context.colors.onBrand, strokeWidth: 2),
                )
                    : Text(
                  canSubmit
                      ? 'Submit Quiz'
                      : isLast
                      ? 'Answer to submit'
                      : 'Next Question',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onBrand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RESULT SCREEN
// -----------------------------------------------------------------------------

class QuizResultScreen extends ConsumerStatefulWidget {
  const QuizResultScreen({
    super.key,
    required this.result,
  });

  final CompletedQuizResult result;

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {

  void _onDone() {
    ref.read(appShellTabProvider.notifier).state = 0;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    final correct = widget.result.score;
    final total = widget.result.total;
    final pct = total == 0 ? 0.0 : correct / total;
    final percentInt = (pct * 100).round();

    final rawTier = widget.result.tier.toLowerCase().trim();
    final tier = const ['excellent', 'good', 'fair', 'failed'].contains(rawTier)
        ? rawTier
        : StreakEngine.quizTier(correct, total);

    Color scoreColor;
    String scoreLabel;
    IconData scoreIcon;
    
    if (pct >= 0.8) {
      scoreColor = context.colors.brand;
      scoreLabel = 'Excellent!';
      scoreIcon = Icons.emoji_events_rounded;
    } else if (pct >= 0.5) {
      scoreColor = context.colors.infoStrong;
      scoreLabel = 'Good effort!';
      scoreIcon = Icons.thumb_up_rounded;
    } else if (pct >= 0.3) {
      scoreColor = context.colors.warningStrong;
      scoreLabel = 'Fair attempt';
      scoreIcon = Icons.trending_up_rounded;
    } else {
      scoreColor = context.colors.dangerStrong;
      scoreLabel = 'Keep practicing';
      scoreIcon = Icons.refresh_rounded;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onDone();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: KeyedSubtree(
child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
                        onPressed: _onDone,
                      ),
                      Text(
                        'Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
  
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(scoreIcon, size: 36, color: scoreColor),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                scoreLabel,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: scoreColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You scored $percentInt%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.colors.surfaceSunken),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatColumn('Correct', correct.toString(), context.colors.brand),
                                    Container(
                                      width: 1,
                                      height: 32,
                                      color: context.colors.border,
                                      margin: const EdgeInsets.symmetric(horizontal: 24),
                                    ),
                                    _buildStatColumn('Total', total.toString(), context.colors.textTertiary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        QuizResultBox(tier: tier),
                        const SizedBox(height: 32),
                        Column(
                          children: [
                            if (widget.result.answers != null && widget.result.answers!.isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => QuizReviewScreen(answers: widget.result.answers!),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: context.colors.border, width: 2),
                                  ),
                                  child: const Text('Review answers'),
                                ),
                              )
                            else
                              Text(
                                "Answer details aren't available on this device.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.colors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _onDone,
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.colors.brand,
                                ),
                                child: const Text('Done'),
                              ),
                            ),
                          ],
                        ),
                      ],
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
  
  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
