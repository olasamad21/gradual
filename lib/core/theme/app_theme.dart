import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const primaryColor = Color(0xFF388E3C);
  static const backgroundColor = Color(0xFFFAFAFA);
  static const surfaceColor = Colors.white;
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);

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

  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: textPrimary),
      displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: textPrimary),
      displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textPrimary),
      headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textPrimary),
      headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textPrimary),
      headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: textPrimary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 12);
          }
          return const TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: textSecondary);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: borderRadius20),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: borderRadius16),
          padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          minimumSize: const Size(double.infinity, 48), // Accessibility
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: borderRadius16),
          padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          minimumSize: const Size(double.infinity, 48), // Accessibility
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(borderRadius: borderRadius16),
          padding: const EdgeInsets.symmetric(horizontal: spacing24, vertical: spacing16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          minimumSize: const Size(double.infinity, 48), // Accessibility
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48), // Accessibility tap targets
        ),
      ),
    );
  }
}
