import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart'; // CHANGED: use existing provider
import '../../router/app_router.dart';

class RootGatekeeper extends ConsumerWidget {
  const RootGatekeeper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CHANGED: authStateChangesProvider already exists in firebase_providers.dart
    // No need for a separate auth_provider.dart file
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const _SplashView(),

      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        });
        return const _SplashView();
      },

      data: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;

          if (user != null) {
            // ✅ Firebase token is cached on device — user stays logged in
            // across app restarts automatically. No extra work needed.
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
                  (_) => false,
            );
            return;
          }

          // Not logged in — go to onboarding.
          // Phase 2 complete: Firebase Auth handles persistence natively.
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        });

        return const _SplashView();
      },
    );
  }
}

/// Branded splash shown while Firebase initializes.
/// No AppBar = no back button possible.
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF388E3C),
      body: Center(
        child: Text(
          'Gradual',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}