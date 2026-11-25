import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'dimens.dart';

abstract final class AppTheme {
  static const String uiFont = 'Almarai';
  static const String literaryFont = 'Amiri';
  static const String bodyFontDefault = uiFont;
  static const String displayFont = literaryFont;

  static ThemeData light({String bodyFont = uiFont}) => _build(Brightness.light, bodyFont);

  static ThemeData dark({String bodyFont = uiFont}) => _build(Brightness.dark, bodyFont);

  static ThemeData _build(Brightness brightness, String bodyFont) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.terracottaLight : AppColors.terracotta,
      onPrimary: isDark ? const Color(0xFF2B100A) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF4B2118) : AppColors.crimsonMist,
      onPrimaryContainer: isDark ? const Color(0xFFFFDBD2) : const Color(0xFF3A1007),
      secondary: isDark ? AppColors.tealLight : AppColors.deepTeal,
      onSecondary: isDark ? const Color(0xFF06262C) : Colors.white,
      secondaryContainer: isDark ? const Color(0xFF143A42) : AppColors.tealMist,
      onSecondaryContainer: isDark ? const Color(0xFFC8F0F7) : const Color(0xFF08272E),
      tertiary: isDark ? AppColors.goldLight : AppColors.warmGold,
      onTertiary: isDark ? const Color(0xFF2B1D04) : Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF433210) : const Color(0xFFF8E9C8),
      onTertiaryContainer: isDark ? const Color(0xFFFFE5B4) : const Color(0xFF332204),
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: isDark ? AppColors.nightSurface : AppColors.paperElevated,
      onSurface: isDark ? AppColors.nightInk : AppColors.ink,
      onSurfaceVariant: isDark ? AppColors.nightMuted : AppColors.inkMuted,
      outline: isDark ? const Color(0xFF6E7285) : const Color(0xFF9C9280),
      outlineVariant: isDark ? AppColors.nightBorder : AppColors.border,
      surfaceContainerHighest: isDark ? AppColors.nightElevated : AppColors.paperSubtle,
    );

    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    final textTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: literaryFont, fontSize: 40, fontWeight: FontWeight.w700, height: 1.35, color: onSurface),
      displayMedium: TextStyle(fontFamily: literaryFont, fontSize: 34, fontWeight: FontWeight.w700, height: 1.35, color: onSurface),
      headlineLarge: TextStyle(fontFamily: literaryFont, fontSize: 28, fontWeight: FontWeight.w700, height: 1.35, color: onSurface),
      displaySmall: TextStyle(
        fontFamily: literaryFont,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.4,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.45,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.45,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.75,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.65,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: muted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: isDark ? AppColors.night : AppColors.paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.night : AppColors.paper,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
    );
  }
}
