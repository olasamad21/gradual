import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/primary_button.dart';
import '../daily_word/daily_word_screen.dart'; // To use your DotPatternPainter
import 'onboarding_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _selectedField = 'software_engineering';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final isLoading = state.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Logic
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 2. Code-Generated Logo (Replacing the image)
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF388E3C), // Your brand green
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF388E3C).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded, // Represents "Gradual" growth
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 3. Typography
                    Text(
                      'Gradual',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Micro-learning for your field. Master one technical concept every day.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // 4. Field Selection
                    _buildSelectionDropdown(isLoading),

                    const SizedBox(height: 32),

                    // 5. Auth Action
                    PrimaryButton(
                      label: 'Continue with Google',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : () async {
                        try {
                          final user = await controller.signInWithGoogle();
                          if (user == null) return;

                          await controller.completeProfile(
                            fieldOfStudy: _selectedField,
                          );

                          if (!mounted) return;

                          // Final Navigation Lock
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/home', (_) => false,
                          );
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sign-in failed. Please try again.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionDropdown(bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedField,
          decoration: const InputDecoration(
            labelText: 'Your Field of Study',
            labelStyle: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w600),
            border: InputBorder.none,
          ),
          items: const [
            DropdownMenuItem(
              value: 'software_engineering',
              child: Text('Software Engineering'),
            ),
            DropdownMenuItem(
              value: 'data_science',
              child: Text('Data Science'),
            ),
          ],
          onChanged: isLoading ? null : (val) {
            if (val != null) setState(() => _selectedField = val);
          },
        ),
      ),
    );
  }
}