import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

export 'app_colors.dart';

abstract final class AppTheme {
  // Spacing Scale
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Radii
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const BorderRadius borderRadius16 = BorderRadius.all(Radius.circular(radius16));
  static const BorderRadius borderRadius20 = BorderRadius.all(Radius.circular(radius20));
  static const BorderRadius borderRadius24 = BorderRadius.all(Radius.circular(radius24));

  // Soft shadows
  static final List<BoxShadow> softShadows = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> hoverShadows = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;
    final inter = GoogleFonts.interTextTheme(base).apply(
      bodyColor: c.textBody,
      displayColor: c.textPrimary,
    );
    TextStyle outfit(FontWeight w) => GoogleFonts.outfit(fontWeight: w, color: c.textPrimary);
    final textTheme = inter.copyWith(
      displayLarge: outfit(FontWeight.w800),
      displayMedium: outfit(FontWeight.w800),
      displaySmall: outfit(FontWeight.w700),
      headlineLarge: outfit(FontWeight.w700),
      headlineMedium: outfit(FontWeight.w700),
      headlineSmall: outfit(FontWeight.w700),
      titleLarge: outfit(FontWeight.w700),
      titleMedium: outfit(FontWeight.w600),
      titleSmall: outfit(FontWeight.w600),
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: c.brand,
      brightness: brightness,
    ).copyWith(
      primary: c.brand,
      onPrimary: c.onBrand,
      surface: c.background,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textTertiary,
      outline: c.borderStrong,
      outlineVariant: c.border,
      error: c.danger,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverseSurface,
    );

    final buttonText = GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      textTheme: textTheme,
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.brand.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: c.brand, fontWeight: FontWeight.w700, fontSize: 12);
          }
          return TextStyle(color: c.textTertiary, fontWeight: FontWeight.w600, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.brand);
          }
          return IconThemeData(color: c.textTertiary);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: borderRadius20),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: borderRadius16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inverseSurface,
        contentTextStyle: TextStyle(color: c.onInverseSurface),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          shape: const RoundedRectangleBorder(borderRadius: borderRadius16),
          padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing16),
          textStyle: buttonText,
          minimumSize: const Size(double.infinity, 48), // Accessibility
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: borderRadius16),
          padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing16),
          textStyle: buttonText,
          minimumSize: const Size(double.infinity, 48), // Accessibility
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          shape: const RoundedRectangleBorder(borderRadius: borderRadius16),
          padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing16),
          textStyle: buttonText,
          minimumSize: const Size(double.infinity, 48), // Accessibility
          side: BorderSide(color: c.border, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.brand),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48), // Accessibility tap targets
        ),
      ),
    );
  }
}
