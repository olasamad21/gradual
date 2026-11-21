import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart'; // CHANGED: use existing provider
import '../../router/app_router.dart';
import '../../shared/widgets/gradual_mark.dart';

class RootGatekeeper extends ConsumerWidget {
  const RootGatekeeper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CHANGED: authStateChangesProvider already exists in firebase_providers.dart
    // No need for a separate auth_provider.dart file
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const _SplashView(),

      error: (_, _) {
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
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.onboarding,
            (_) => false,
          );
        });

        return const _SplashView();
      },
    );
  }
}

/// Shown while Firebase initializes. Matches the native launch screen
/// (see flutter_native_splash in pubspec.yaml) so the hand-off is seamless.
/// No AppBar = no back button possible.
class _SplashView extends StatelessWidget {
  const _SplashView();

  /// Launch screen colours, same as the native splash config.
  static const _lightBackground = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    // Follow the device setting, as the native splash does.
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.dark.background : _lightBackground,
      body: Center(
        child: GradualMark(
          size: 96,
          color: isDark ? AppColors.dark.brand : Colors.white,
        ),
      ),
    );
  }
}
