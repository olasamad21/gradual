import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_providers.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class GradualApp extends StatelessWidget {
  const GradualApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = ProviderScope.containerOf(context).read(
      authStateChangesProvider,
    );

    return MaterialApp(
      title: 'Gradual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: authState.maybeWhen(
        data: (user) => user == null ? AppRoutes.onboarding : AppRoutes.home,
        orElse: () => AppRoutes.onboarding,
      ),
    );
  }
}

