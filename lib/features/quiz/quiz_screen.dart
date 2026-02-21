import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Use the full package path instead of ../ to avoid path errors
import 'package:gradual/features/daily_word/daily_word_providers.dart';
import 'package:gradual/core/enums/difficulty_level.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String difficulty;

  // We now pass the difficulty directly so we don't need a second overlay here
  const QuizScreen({super.key, required this.difficulty});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  String? selectedOption;
  bool isSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(todayContentProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('${widget.difficulty[0].toUpperCase()}${widget.difficulty.substring(1)} Quiz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: contentAsync.when(
        data: (content) {
          if (content == null) return const Center(child: Text("No quiz available for today."));

          // Helper to map the string difficulty to your model's Enum
          final level = DifficultyLevel.values.firstWhere(
                (e) => e.name == (widget.difficulty == 'tech_lead' ? 'techLead' : widget.difficulty),
            orElse: () => DifficultyLevel.junior,
          );

          final quiz = content.quizFor(level);
          if (quiz == null) return const Center(child: Text("Questions for this level aren't ready yet."));

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Bar - Matches your premium UI style
                LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFF388E3C),
                  minHeight: 8,
                ),
                const SizedBox(height: 32),

                Text(
                  quiz.question,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
                ),
                const SizedBox(height: 32),

                // Options List mapped from your QuizItem model
                ...quiz.options.map((option) => _buildOptionCard(option, quiz.answer)),

                const Spacer(),

                // Dynamic Action Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: selectedOption == null ? null : () {
                      if (!isSubmitted) {
                        setState(() => isSubmitted = true);
                      } else {
                        Navigator.pop(context); // Returns to Home Screen
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                        isSubmitted ? "Return to Home" : "Check Answer",
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF388E3C))),
        error: (error, _) => Center(child: Text("Error loading quiz: $error")),
      ),
    );
  }

  Widget _buildOptionCard(String option, String correctAnswer) {
    bool isSelected = selectedOption == option;
    bool isCorrect = isSubmitted && option == correctAnswer;
    bool isWrong = isSubmitted && isSelected && option != correctAnswer;

    Color borderColor = Colors.grey[300]!;
    Color bgColor = Colors.white;

    if (isSelected) borderColor = const Color(0xFF388E3C);
    if (isCorrect) {
      borderColor = Colors.green;
      bgColor = Colors.green.withOpacity(0.1);
    } else if (isWrong) {
      borderColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: isSubmitted ? null : () => setState(() => selectedOption = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(option, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            if (isCorrect) const Icon(Icons.check_circle, color: Colors.green),
            if (isWrong) const Icon(Icons.cancel, color: Colors.red),
          ],
        ),
      ),
    );
  }
}