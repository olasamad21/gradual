import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gradual/core/enums/difficulty_level.dart';
import 'package:gradual/features/daily_word/daily_word_providers.dart';
import 'package:gradual/features/daily_word/daily_word_screen.dart';
import 'package:gradual/features/quiz/quiz_providers.dart';
import 'package:gradual/features/quiz/quiz_result_cache_provider.dart';
import 'quiz_models.dart';

// ─────────────────────────────────────────────────────────────
// QUIZ SCREEN
// ─────────────────────────────────────────────────────────────

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.difficulty});
  final String difficulty;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with SingleTickerProviderStateMixin {
  late final DifficultyLevel _level;
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  final Map<int, int> _selections = {};
  bool _isSubmitting = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _level = DifficultyLevel.values.firstWhere(
          (e) => e.name ==
          (widget.difficulty == 'tech_lead' ? 'techLead' : widget.difficulty),
      orElse: () => DifficultyLevel.junior,
    );
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

  void _loadQuestions(List<QuizQuestion> questions) {
    if (questions.isNotEmpty && _questions.length != questions.length) {
      _questions = questions;
    }
  }

  void _selectOption(int index) {
    setState(() => _selections[_currentIndex] = index);
  }

  void _goNext() {
    if (_currentIndex < _questions.length - 1) {
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

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final answers = <QuizAnswer>[];
    for (var i = 0; i < _questions.length; i++) {
      final selected = _selections[i] ?? 0;
      answers.add(QuizAnswer(
        question: _questions[i],
        selectedIndex: selected,
      ));
    }

    final correctCount = answers.where((a) => a.isCorrect).length;

    // Save to Firestore
    await ref.read(quizControllerProvider.notifier).finalizeResults(
      difficulty: _level,
      correctCount: correctCount,
      totalQuestions: _questions.length,
    );

    // Cache answers so result screen can be reopened later
    final cache = Map<String, List<QuizAnswer>>.from(
        ref.read(quizResultCacheProvider));
    cache[_level.id] = answers;
    ref.read(quizResultCacheProvider.notifier).state = cache;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          allAnswers: cache,
          initialDifficultyId: _level.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(todayContentProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF388E3C)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (content) {
          if (content == null) {
            return const Center(child: Text('No quiz available for today.'));
          }

          final questions = buildQuizFromContent(content, _level);
          _loadQuestions(questions);

          final displayQuestions =
          _questions.isNotEmpty ? _questions : questions;

          if (displayQuestions.isEmpty) {
            return const Center(
              child: Text("Questions for this level aren't ready yet."),
            );
          }

          final safeIndex =
          _currentIndex.clamp(0, displayQuestions.length - 1);
          final question = displayQuestions[safeIndex];
          final selectedIndex = _selections[safeIndex];
          final isLast = safeIndex == displayQuestions.length - 1;
          final allAnswered = _selections.length == displayQuestions.length;

          return SafeArea(
            child: CustomPaint(
              painter: DotPatternPainter(),
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildProgressBar(displayQuestions.length),
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final levelLabel = widget.difficulty == 'tech_lead'
        ? 'Tech Lead'
        : '${widget.difficulty[0].toUpperCase()}${widget.difficulty.substring(1)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              levelLabel,
              style: const TextStyle(
                color: Color(0xFF388E3C),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_currentIndex + 1} / ${_questions.isNotEmpty ? _questions.length : 0}',
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
    final progress =
    total == 0 ? 0.0 : ((_currentIndex + 1) / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFFE5E7EB),
          valueColor:
          const AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _questionTypeLabel(question.type),
              style: const TextStyle(
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

  String _questionTypeLabel(String type) {
    switch (type) {
      case 'true_false':
        return 'TRUE / FALSE';
      case 'fill_blank':
        return 'FILL IN THE BLANK';
      default:
        return 'MULTIPLE CHOICE';
    }
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
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF388E3C).withOpacity(0.05)
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
              color: Colors.black.withOpacity(0.02),
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
                    color:
                    isSelected ? Colors.white : const Color(0xFF9CA3AF),
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
  }) {
    final bool canSubmit = isLast && allAnswered && !_isSubmitting;
    final bool canGoNext = !isLast && selectedIndex != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  border: Border.all(
                      color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF374151)),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: canSubmit
                    ? _submitQuiz
                    : canGoNext
                    ? _goNext
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
                child: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
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

// ─────────────────────────────────────────────────────────────
// RESULT SCREEN  (multi-category tabs)
// ─────────────────────────────────────────────────────────────

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    super.key,
    required this.allAnswers,
    required this.initialDifficultyId,
  });

  /// All submitted answers keyed by difficulty id.
  final Map<String, List<QuizAnswer>> allAnswers;

  /// Which tab to open first.
  final String initialDifficultyId;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  late String _activeDifficultyId;

  static const _order = ['junior', 'senior', 'lead'];
  static const _labels = {
    'junior': 'Junior',
    'senior': 'Senior',
    'lead': 'Tech Lead',
  };
  static const _colors = {
    'junior': Color(0xFF22C55E),
    'senior': Color(0xFF3B82F6),
    'lead': Color(0xFF8B5CF6),
  };

  @override
  void initState() {
    super.initState();
    _activeDifficultyId = widget.initialDifficultyId;
  }

  List<String> get _submittedIds => _order
      .where((id) => widget.allAnswers.containsKey(id))
      .toList();

  @override
  Widget build(BuildContext context) {
    final answers = widget.allAnswers[_activeDifficultyId] ?? [];
    final correct = answers.where((a) => a.isCorrect).length;
    final total = answers.length;
    final percent = total == 0 ? 0 : (correct / total * 100).round();
    final color = _colors[_activeDifficultyId] ?? const Color(0xFF388E3C);

    final Color scoreColor;
    final String scoreLabel;
    final IconData scoreIcon;

    if (percent >= 80) {
      scoreColor = const Color(0xFF22C55E);
      scoreLabel = 'Excellent!';
      scoreIcon = Icons.emoji_events_rounded;
    } else if (percent >= 50) {
      scoreColor = const Color(0xFFF59E0B);
      scoreLabel = 'Good effort!';
      scoreIcon = Icons.thumb_up_rounded;
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreLabel = 'Keep practicing!';
      scoreIcon = Icons.refresh_rounded;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomPaint(
        painter: DotPatternPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Color(0xFF1F2937)),
                      onPressed: () => Navigator.popUntil(
                          context, (route) => route.isFirst),
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

              // ── Category tab bars ────────────────────────────
              if (_submittedIds.length > 1) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: _submittedIds.asMap().entries.map((entry) {
                      final id = entry.value;
                      final isActive = id == _activeDifficultyId;
                      final barColor = _colors[id] ?? const Color(0xFF388E3C);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _activeDifficultyId = id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(
                              right: entry.key < _submittedIds.length - 1
                                  ? 8
                                  : 0,
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? barColor.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? barColor
                                    : const Color(0xFFE5E7EB),
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _labels[id] ?? id,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? barColor
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Score mini bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: () {
                                      final a = widget.allAnswers[id] ?? [];
                                      if (a.isEmpty) return 0.0;
                                      return a
                                          .where((x) => x.isCorrect)
                                          .length /
                                          a.length;
                                    }(),
                                    backgroundColor:
                                    const Color(0xFFE5E7EB),
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        barColor),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // ── Score content ────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      // Score card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                                color: scoreColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(scoreIcon,
                                  color: scoreColor, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              scoreLabel,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: scoreColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$correct out of $total correct',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 110,
                                  height: 110,
                                  child: CircularProgressIndicator(
                                    value: percent / 100,
                                    strokeWidth: 10,
                                    backgroundColor:
                                    const Color(0xFFF3F4F6),
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        scoreColor),
                                  ),
                                ),
                                Text(
                                  '$percent%',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: scoreColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stat row
                      Row(
                        children: [
                          _buildStatCard(
                            label: 'Correct',
                            value: '$correct',
                            color: const Color(0xFF22C55E),
                            icon: Icons.check_circle_rounded,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            label: 'Wrong',
                            value: '${total - correct}',
                            color: const Color(0xFFEF4444),
                            icon: Icons.cancel_rounded,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            label: 'Questions',
                            value: '$total',
                            color: color,
                            icon: Icons.quiz_rounded,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Review button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizReviewScreen(
                                  answers: answers),
                            ),
                          ),
                          icon: const Icon(Icons.rate_review_rounded,
                              color: Colors.white),
                          label: const Text(
                            'Review Answers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.popUntil(
                            context,
                                (route) => route.isFirst,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFE5E7EB), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REVIEW SCREEN
// ─────────────────────────────────────────────────────────────

class QuizReviewScreen extends StatelessWidget {
  const QuizReviewScreen({super.key, required this.answers});
  final List<QuizAnswer> answers;

  @override
  Widget build(BuildContext context) {
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
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Color(0xFF1F2937)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Review Answers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFF388E3C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${answers.where((a) => a.isCorrect).length}/${answers.length}',
                        style: const TextStyle(
                          color: Color(0xFF388E3C),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: answers.length,
                  itemBuilder: (context, i) =>
                      _ReviewCard(answer: answers[i], index: i),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.answer, required this.index});
  final QuizAnswer answer;
  final int index;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;
    final question = answer.question;
    final isCorrect = answer.isCorrect;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF1F2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: question.options.asMap().entries.map((e) {
                final i = e.key;
                final text = e.value;
                final isUserAnswer = i == answer.selectedIndex;
                final isCorrectAnswer = i == question.correctIndex;

                Color bgColor = const Color(0xFFF9FAFB);
                Color borderColor = const Color(0xFFE5E7EB);
                Color textColor = const Color(0xFF374151);
                Widget? badge;

                if (isCorrectAnswer) {
                  bgColor = const Color(0xFFDCFCE7);
                  borderColor = const Color(0xFF22C55E);
                  textColor = const Color(0xFF15803D);
                  badge = Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Correct',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  );
                } else if (isUserAnswer && !isCorrectAnswer) {
                  bgColor = const Color(0xFFFEE2E2);
                  borderColor = const Color(0xFFEF4444);
                  textColor = const Color(0xFFB91C1C);
                  badge = Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Your answer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Text(String.fromCharCode(65 + i),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              fontSize: 14)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(text,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor))),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        badge,
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() => _showExplanation = !_showExplanation),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(
                    _showExplanation
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF388E3C),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  const Text('See explanation',
                      style: TextStyle(
                          color: Color(0xFF388E3C),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          if (_showExplanation)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(question.explanation,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF166534),
                              height: 1.5)),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}