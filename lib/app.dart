import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class GradualApp extends StatelessWidget {
  const GradualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gradual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // FIXED: Always start at root so RootGatekeeper decides where to go.
      // Never read auth state here — it's always loading on cold start.
      initialRoute: AppRoutes.root,
    );
  }
}