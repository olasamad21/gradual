import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/auth/root_gatekeeper.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../features/quiz/quiz_screen.dart';
import '../shared/widgets/placeholder_screen.dart';

abstract final class AppRoutes {
  static const root       = '/';
  static const onboarding = '/onboarding';
  // No /sign-in — onboarding screen IS the sign-in screen
  static const home       = '/home';
  static const quiz       = '/quiz';
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Protect authenticated routes. If a user lands here via a direct URL on web
    // while signed out (or while Firebase is still initializing), reroute them 
    // to the RootGatekeeper to handle auth state.
    final isAuthRoute = settings.name == AppRoutes.home ||
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
          builder: (_) => const AppShell(),
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