import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'quiz_models.dart';

class QuizReviewScreen extends StatefulWidget {
  const QuizReviewScreen({
    super.key,
    required this.answers,
    this.initialIndex = 0,
  });

  final List<QuizAnswer> answers;
  final int initialIndex;

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Review answers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: KeyedSubtree(
child: SafeArea(
          child: widget.answers.isEmpty
              ? const Center(child: Text('No answers to review.'))
              : Column(
                  children: [
                    const SizedBox(height: 16),
                    Text('Question ${_current + 1} of ${widget.answers.length}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(widget.answers.length, (index) {
                        final answer = widget.answers[index];
                        final isCorrect = answer.isCorrect;
                        final isActive = index == _current;

                        return Semantics(
                          button: true,
                          selected: isActive,
                          label: 'Question ${index + 1}, ${isCorrect ? 'correct' : 'incorrect'}',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey('review_box_$index'),
                              onTap: () {
                                if (MediaQuery.disableAnimationsOf(context)) {
                                  _pageController.jumpToPage(index);
                                } else {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isCorrect ? context.colors.successSoft : context.colors.dangerSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCorrect ? context.colors.successBright : context.colors.danger,
                                    width: isActive ? 3.0 : 1.5,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isCorrect ? context.colors.onSuccessSoft : context.colors.onDangerSoft,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Icon(
                                        isCorrect ? Icons.check : Icons.close,
                                        size: 12,
                                        color: isCorrect ? context.colors.onSuccessSoft : context.colors.onDangerSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.answers.length,
                        onPageChanged: (index) {
                          setState(() {
                            _current = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _buildReviewCard(
                              index: index,
                              answer: widget.answers[index],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }


  Widget _buildReviewCard({required int index, required QuizAnswer answer}) {
    final isCorrect = answer.isCorrect;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? context.colors.successSoft : context.colors.dangerSoft,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.02),
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
                  color: isCorrect ? context.colors.success : context.colors.dangerStrong,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  color: context.colors.onBrand,
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
                        color: isCorrect ? context.colors.success : context.colors.dangerStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      answer.question.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
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
            Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Divider(color: context.colors.surfaceSunken, height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: context.colors.warningStrong),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer.question.explanation,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textSecondary,
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
        color: isCorrect ? context.colors.successSoft : context.colors.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? context.colors.successBorder : context.colors.dangerBorder,
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
                color: isCorrect ? context.colors.onSuccessSoft : context.colors.onDangerSoft,
              ),
            ),
          ),
          if (isUserPick)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isCorrect ? context.colors.onSuccessSoft : context.colors.onDangerSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Your Answer',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isCorrect ? context.colors.successSoft : context.colors.dangerSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
