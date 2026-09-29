import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    // Protect authenticated routes. If a user lands here via a direct URL on web
    // while signed out (or while Firebase is still initializing), reroute them 
    // to the RootGatekeeper to handle auth state.
    final isAuthRoute = settings.name == AppRoutes.home ||
        settings.name == AppRoutes.profile ||
        settings.name == AppRoutes.learning ||
        settings.name == AppRoutes.quiz;

    if (isAuthRoute && FirebaseAuth.instance.currentUser == null) {
      return MaterialPageRoute(builder: (_) => const RootGatekeeper());
    }

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
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const QuizScreen(),
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