import 'package:flutter/material.dart';

/// Semantic colour tokens for Gradual.
///
/// Widgets read colours through `context.colors` instead of hardcoding hex
/// values, so light and dark themes stay in sync from one place.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.onBrand,
    required this.success,
    required this.successBright,
    required this.successSoft,
    required this.successBorder,
    required this.onSuccessSoft,
    required this.danger,
    required this.dangerStrong,
    required this.dangerSoft,
    required this.dangerBorder,
    required this.onDangerSoft,
    required this.warning,
    required this.warningStrong,
    required this.caution,
    required this.info,
    required this.infoStrong,
    required this.accentPurple,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.heatmapEmpty,
    required this.shadow,
    required this.dotPattern,
    required this.webBackdrop,
    required this.wordAccents,
  });

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;

  // Text, strongest to weakest
  final Color textPrimary;
  final Color textBody;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;

  // Brand
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color onBrand;

  // Semantic
  final Color success;
  final Color successBright;
  final Color successSoft;
  final Color successBorder;
  final Color onSuccessSoft;
  final Color danger;
  final Color dangerStrong;
  final Color dangerSoft;
  final Color dangerBorder;
  final Color onDangerSoft;
  final Color warning;
  final Color warningStrong;
  final Color caution;
  final Color info;
  final Color infoStrong;
  final Color accentPurple;

  // Misc
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color heatmapEmpty;
  final Color shadow;
  final Color dotPattern;
  final Color webBackdrop;

  /// Per-word accent colours on the concept cards, cycled by index.
  final List<Color> wordAccents;

  Color wordAccent(int index) => wordAccents[index % wordAccents.length];

  static const light = AppColors(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF9FAFB),
    surfaceSunken: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    textPrimary: Color(0xFF1F2937),
    textBody: Color(0xFF374151),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    brand: Color(0xFF388E3C),
    brandStrong: Color(0xFF1B5E20),
    brandSoft: Color(0xFFC8E6C9),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    successBright: Color(0xFF22C55E),
    successSoft: Color(0xFFF0FDF4),
    successBorder: Color(0xFFBBF7D0),
    onSuccessSoft: Color(0xFF166534),
    danger: Color(0xFFEF4444),
    dangerStrong: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
    dangerBorder: Color(0xFFFECACA),
    onDangerSoft: Color(0xFF991B1B),
    warning: Color(0xFFF59E0B),
    warningStrong: Color(0xFFD97706),
    caution: Color(0xFFF97316),
    info: Color(0xFF3B82F6),
    infoStrong: Color(0xFF2563EB),
    accentPurple: Color(0xFF8B5CF6),
    inverseSurface: Color(0xFF1F2937),
    onInverseSurface: Color(0xFFFFFFFF),
    heatmapEmpty: Color(0xFFEAECEF),
    shadow: Color(0xFF000000),
    dotPattern: Color(0x66D1D5DB),
    webBackdrop: Color(0xFFE5E7EB),
    wordAccents: [
      Color(0xFF1D4ED8), // blue
      Color(0xFF6D28D9), // purple
      Color(0xFF0F766E), // teal
    ],
  );

  static const dark = AppColors(
    background: Color(0xFF0F1115),
    surface: Color(0xFF181B22),
    surfaceMuted: Color(0xFF1D2129),
    surfaceSunken: Color(0xFF232833),
    border: Color(0xFF2C323D),
    borderStrong: Color(0xFF3A414E),
    textPrimary: Color(0xFFF3F4F6),
    textBody: Color(0xFFD1D5DB),
    textSecondary: Color(0xFFB4BAC4),
    textTertiary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    brand: Color(0xFF4CAF50),
    brandStrong: Color(0xFF81C784),
    brandSoft: Color(0xFF1F3A22),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF22C55E),
    successBright: Color(0xFF4ADE80),
    successSoft: Color(0xFF12291B),
    successBorder: Color(0xFF1F4D2E),
    onSuccessSoft: Color(0xFF86EFAC),
    danger: Color(0xFFF87171),
    dangerStrong: Color(0xFFEF4444),
    dangerSoft: Color(0xFF2D1617),
    dangerBorder: Color(0xFF5B2526),
    onDangerSoft: Color(0xFFFCA5A5),
    warning: Color(0xFFFBBF24),
    warningStrong: Color(0xFFF59E0B),
    caution: Color(0xFFFB923C),
    info: Color(0xFF60A5FA),
    infoStrong: Color(0xFF3B82F6),
    accentPurple: Color(0xFFA78BFA),
    inverseSurface: Color(0xFFF3F4F6),
    onInverseSurface: Color(0xFF111827),
    heatmapEmpty: Color(0xFF262B35),
    shadow: Color(0xFF000000),
    dotPattern: Color(0x33374151),
    webBackdrop: Color(0xFF08090B),
    wordAccents: [
      Color(0xFF60A5FA), // blue
      Color(0xFFA78BFA), // purple
      Color(0xFF2DD4BF), // teal
    ],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textBody: l(textBody, other.textBody),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textMuted: l(textMuted, other.textMuted),
      brand: l(brand, other.brand),
      brandStrong: l(brandStrong, other.brandStrong),
      brandSoft: l(brandSoft, other.brandSoft),
      onBrand: l(onBrand, other.onBrand),
      success: l(success, other.success),
      successBright: l(successBright, other.successBright),
      successSoft: l(successSoft, other.successSoft),
      successBorder: l(successBorder, other.successBorder),
      onSuccessSoft: l(onSuccessSoft, other.onSuccessSoft),
      danger: l(danger, other.danger),
      dangerStrong: l(dangerStrong, other.dangerStrong),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      dangerBorder: l(dangerBorder, other.dangerBorder),
      onDangerSoft: l(onDangerSoft, other.onDangerSoft),
      warning: l(warning, other.warning),
      warningStrong: l(warningStrong, other.warningStrong),
      caution: l(caution, other.caution),
      info: l(info, other.info),
      infoStrong: l(infoStrong, other.infoStrong),
      accentPurple: l(accentPurple, other.accentPurple),
      inverseSurface: l(inverseSurface, other.inverseSurface),
      onInverseSurface: l(onInverseSurface, other.onInverseSurface),
      heatmapEmpty: l(heatmapEmpty, other.heatmapEmpty),
      shadow: l(shadow, other.shadow),
      dotPattern: l(dotPattern, other.dotPattern),
      webBackdrop: l(webBackdrop, other.webBackdrop),
      wordAccents: [for (var i = 0; i < wordAccents.length; i++) l(wordAccents[i], other.wordAccents[i % other.wordAccents.length])],
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
