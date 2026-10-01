import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gradual/features/quiz/quiz_providers.dart';
import 'package:gradual/features/quiz/quiz_result_cache_provider.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'quiz_models.dart';
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

  Future<void> _submitQuiz(QuizSessionState state) async {
    final questions = state.questions;
    final answers = <QuizAnswer>[];
    for (var i = 0; i < questions.length; i++) {
      final selected = _selections[i] ?? 0;
      answers.add(QuizAnswer(
        question: questions[i],
        selectedIndex: selected,
      ));
    }

    final correctCount = answers.where((a) => a.isCorrect).length;

    final result = await ref.read(quizControllerProvider.notifier).submitQuiz(_sessionDate!, correctCount, questions.length);
    
    if (!mounted) return;

    if (result == QuizSaveResult.alreadyTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz already taken this week.')),
      );
      setState(() => _hasStarted = false);
      return;
    }

    await ref.read(quizResultCacheProvider).saveAnswers(state.sessionDateId, answers);

    final completedResult = CompletedQuizResult(
      sessionDateId: state.sessionDateId,
      score: correctCount,
      total: questions.length,
      tier: StreakEngine.quizTier(correctCount, questions.length),
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
    final today = DateTime.now();
    final buttonState = ref.watch(quizButtonStateProvider(today));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_rounded, size: 64, color: Color(0xFF388E3C)),
              const SizedBox(height: 24),
              const Text('Weekly Quiz', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(buttonState.label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),
              if (buttonState.isEnabled)
                ElevatedButton(
                  onPressed: () async {
                    if (buttonState.isCompleted) {
                      final result = await ref.read(completedQuizResultProvider.future);
                      if (context.mounted) {
                        if (result != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizResultScreen(result: result),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Couldn't load your results. Please try again.")),
                          );
                        }
                      }
                      return;
                    }
                    setState(() {
                      _hasStarted = true;
                      _sessionDate = DateTime.now();
                    });
                    ref.read(quizControllerProvider.notifier).generateQuiz(_sessionDate!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF388E3C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                  ),
                  child: Text(buttonState.isCompleted ? 'View Results' : 'Start Quiz'),
                ),
            ],
          ),
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
      backgroundColor: const Color(0xFFFAFAFA),
      body: sessionAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF388E3C)),
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

          return SafeArea(
            child: CustomPaint(
              painter: DotPatternPainter(),
              child: Column(
                children: [
                  _buildHeader(context, displayQuestions.length),
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
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
            onPressed: () => ref.read(appShellTabProvider.notifier).state = 0,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Quiz',
              style: TextStyle(
                color: Color(0xFF388E3C),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_currentIndex + 1} / $total',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
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
          backgroundColor: const Color(0xFFE5E7EB),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'MULTIPLE CHOICE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
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
              ? const Color(0xFF388E3C).withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF388E3C)
                : const Color(0xFFE5E7EB),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                    ? const Color(0xFF388E3C)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  optionLetter,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                  height: 1.4,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF388E3C), size: 20),
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
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF374151)),
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
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF388E3C),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Text(
                  canSubmit
                      ? 'Submit Quiz'
                      : isLast
                      ? 'Answer to submit'
                      : 'Next Question',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    super.key,
    required this.result,
  });

  final CompletedQuizResult result;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {

  @override
  Widget build(BuildContext context) {

    final correct = widget.result.score;
    final total = widget.result.total;
    final pct = total == 0 ? 0.0 : correct / total;
    final percentInt = (pct * 100).round();

    Color scoreColor;
    String scoreLabel;
    IconData scoreIcon;
    
    if (pct >= 0.8) {
      scoreColor = const Color(0xFF388E3C);
      scoreLabel = 'Excellent!';
      scoreIcon = Icons.emoji_events_rounded;
    } else if (pct >= 0.5) {
      scoreColor = const Color(0xFF2563EB);
      scoreLabel = 'Good effort!';
      scoreIcon = Icons.thumb_up_rounded;
    } else if (pct >= 0.3) {
      scoreColor = const Color(0xFFD97706);
      scoreLabel = 'Fair attempt';
      scoreIcon = Icons.trending_up_rounded;
    } else {
      scoreColor = const Color(0xFFDC2626);
      scoreLabel = 'Keep practicing';
      scoreIcon = Icons.refresh_rounded;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomPaint(
        painter: DotPatternPainter(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    ),
                    const Text(
                      'Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF3F4F6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildStatColumn('Correct', correct.toString(), const Color(0xFF388E3C)),
                                  Container(
                                    width: 1,
                                    height: 32,
                                    color: const Color(0xFFE5E7EB),
                                    margin: const EdgeInsets.symmetric(horizontal: 24),
                                  ),
                                  _buildStatColumn('Total', total.toString(), const Color(0xFF6B7280)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (widget.result.answers != null) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Review Answers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...widget.result.answers!.asMap().entries.map(
                              (e) => _buildReviewCard(
                            index: e.key,
                            answer: e.value,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          "Answer details aren't available on this device.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({required int index, required QuizAnswer answer}) {
    final isCorrect = answer.isCorrect;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCorrect ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      answer.question.text,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReviewOption(
            text: answer.question.options[answer.question.correctIndex],
            isCorrect: true,
            isUserPick: isCorrect,
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            _buildReviewOption(
              text: answer.question.options[answer.selectedIndex],
              isCorrect: false,
              isUserPick: true,
            ),
          ],
          if (answer.question.explanation.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Divider(color: Color(0xFFF3F4F6), height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer.question.explanation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewOption({
    required String text,
    required bool isCorrect,
    required bool isUserPick,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isUserPick ? FontWeight.w600 : FontWeight.w500,
                color: isCorrect ? const Color(0xFF166534) : const Color(0xFF991B1B),
              ),
            ),
          ),
          if (isUserPick)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFF166534) : const Color(0xFF991B1B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Your Answer',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
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
