import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/primary_button.dart';
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
      appBar: AppBar(
        title: const Text('Welcome to Gradual'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Micro-learning for your field',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in with Google, pick your field of study, and start getting one concept a day.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedField,
                  decoration: const InputDecoration(
                    labelText: 'Field of study',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'software_engineering',
                      child: Text('Software Engineering'),
                    ),
                    // Future fields (e.g., Nursing, Law) can be added here.
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _selectedField = value;
                            });
                          }
                        },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue with Google',
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          try {
                            final user = await controller.signInWithGoogle();
                            if (user == null) return;

                            await controller.completeProfile(
                              fieldOfStudy: _selectedField,
                            );

                            if (!mounted) return;
                            // After onboarding, navigate to home (daily word).
                            Navigator.of(context).pushReplacementNamed('/home');
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Something went wrong signing in. Please try again.',
                                ),
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 16),
                if (state.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LoadingIndicator(
                      label: 'Retrying…',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

