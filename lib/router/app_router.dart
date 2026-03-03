import 'package:flutter/material.dart';

import '../features/auth/root_gatekeeper.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/daily_word/daily_word_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../shared/widgets/placeholder_screen.dart';

abstract final class AppRoutes {
  static const root       = '/';
  static const onboarding = '/onboarding';
  // No /sign-in — onboarding screen IS the sign-in screen
  static const home       = '/home';
  static const profile    = '/profile';
  static const learning   = '/learning';
  static const quiz       = '/quiz';
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RootGatekeeper(),
        );
      case AppRoutes.onboarding:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OnboardingScreen(),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DailyWordScreen(),
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ProfileScreen(),
        );
      case AppRoutes.learning:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const PlaceholderScreen(
            title: 'Learning',
            message: 'Word card flip + Test Knowledge CTA (FR-05, FR-07).',
          ),
        );
      case AppRoutes.quiz:
        final difficulty = settings.arguments as String? ?? 'junior';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => QuizScreen(difficulty: difficulty),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PlaceholderScreen(
            title: 'Not Found',
            message: 'Unknown route: ${settings.name}',
          ),
        );
    }
  }
}