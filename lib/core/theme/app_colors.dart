import 'package:flutter/material.dart';

/// Warm parchment & Mesopotamian calligraphy palette tailored for prolonged
/// Arabic reading in classrooms and homes.
abstract final class AppColors {
  // Light palette — warm cream paper, deep walnut ink, terracotta & teal accents.
  static const Color paper = Color(0xFFFAF6EE);
  static const Color paperElevated = Color(0xFFFFFCF6);
  static const Color paperSubtle = Color(0xFFF2EBDC);
  static const Color ink = Color(0xFF232229);
  static const Color inkMuted = Color(0xFF5C5866);
  static const Color border = Color(0xFFE2D8C5);

  static const Color terracotta = Color(0xFF9E3B26);
  static const Color deepTeal = Color(0xFF1B5E6B);
  static const Color warmGold = Color(0xFFC28B2C);
  static const Color sageGreen = Color(0xFF3E704F);
  static const Color crimsonMist = Color(0xFFF6E4DF);
  static const Color tealMist = Color(0xFFDDECEF);

  // Dark palette — soft charcoal slate with low-glare warm sand text.
  static const Color night = Color(0xFF15161B);
  static const Color nightSurface = Color(0xFF1E2028);
  static const Color nightElevated = Color(0xFF262934);
  static const Color nightInk = Color(0xFFF3EDE0);
  static const Color nightMuted = Color(0xFFB5AE9E);
  static const Color nightBorder = Color(0xFF353846);

  static const Color terracottaLight = Color(0xFFE5856E);
  static const Color tealLight = Color(0xFF6CC4D4);
  static const Color goldLight = Color(0xFFE7BA64);
  static const Color greenLight = Color(0xFF7BC494);

  // Semantic compatibility names used by the art curriculum widgets.
  static const Color clay = terracotta;
  static const Color claySoft = crimsonMist;
  static const Color indigo = deepTeal;
  static const Color indigoSoft = tealMist;
  static const Color ochre = warmGold;
  static const Color ochreSoft = Color(0xFFF8E9C8);
  static const Color leaf = sageGreen;
  static const Color leafSoft = Color(0xFFDDEBDF);
  static const Color inkSoft = inkMuted;
  static const Color paperHigh = paperElevated;

  static Color fromAccent(String accent, bool isDark) {
    if (accent == 'ink') return isDark ? nightMuted : inkMuted;
    return resolveAccent(accent, isDark ? Brightness.dark : Brightness.light);
  }

  /// Resolves a semantic accent token from JSON (`primary`, `secondary`, `gold`, `green`).
  static Color resolveAccent(String key, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (key) {
      case 'secondary':
        return isDark ? tealLight : deepTeal;
      case 'gold':
        return isDark ? goldLight : warmGold;
      case 'green':
        return isDark ? greenLight : sageGreen;
      case 'primary':
      default:
        return isDark ? terracottaLight : terracotta;
    }
  }
}
