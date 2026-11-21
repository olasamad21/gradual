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
      darkTheme: AppTheme.dark,
      // Dark tokens exist but screens are not yet reviewed in dark mode.
      // Switch to ThemeMode.system once they are.
      themeMode: ThemeMode.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // FIXED: Always start at root so RootGatekeeper decides where to go.
      // Never read auth state here — it's always loading on cold start.
      initialRoute: AppRoutes.root,
      // NEW: Wrap the entire Navigator (including dialogs/bottom sheets)
      builder: (context, child) {
        return Container(
          // Background color for the empty space on wide web screens
          color: context.colors.webBackdrop,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              // ClipRect ensures nothing bleeds outside the 500px column
              child: ClipRect(
                child: child!,
              ),
            ),
          ),
        );
      },
    );
  }
}