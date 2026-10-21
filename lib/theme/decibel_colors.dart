import 'package:flutter/material.dart';
import '../services/theme_preference_service.dart';

class DecibelColors {
  // Brand & Accent Colors (Shared)
  static const Color purple = Color(0xFF7A6BE6);
  static const Color purpleLight = Color(0xFF9E8EFA);
  static const Color purpleActive = Color(0xFF8B7BF7);
  static const Color pink = Color(0xFFEA88A8);
  static const Color peach = Color(0xFFE78B6E);
  static const Color mint = Color(0xFF4DBB99);
  static const Color lavender = Color(0xFFD1CDFA);
  static const Color lavenderSubtle = Color(0xFF1E1C2B);
  static const Color heartPink = Color(0xFFFF4D79);
  static const Color blue = Color(0xFF4A71B5);
  static const Color green = purple;
  static const Color greenActive = purpleActive;

  // Dark Theme Palette (Black Theme)
  static const Color darkBackground = Color(0xFF0E0C17);
  static const Color darkSurface = Color(0xFF141222);
  static const Color darkCard = Color(0xFF1B192A);
  static const Color darkElevated = Color(0xFF232034);
  static const Color darkElevatedHover = Color(0xFF2E2A42);
  static const Color darkNavy = Color(0xFF141221);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8A9F);
  static const Color darkTextSubtle = Color(0xFF6C6782);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFFAF9FD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF2EFFB);
  static const Color lightElevated = Color(0xFFE7E2F5);
  static const Color lightElevatedHover = Color(0xFFDDD7EE);
  static const Color lightNavy = Color(0xFF191E53);
  static const Color lightTextPrimary = Color(0xFF111224);
  static const Color lightTextSecondary = Color(0xFF66627A);
  static const Color lightTextSubtle = Color(0xFF9E99B0);

  // Dynamic Theme Evaluation
  static bool get isDark => ThemePreferenceService.isDark;

  static Color get navy => isDark ? darkNavy : lightNavy;
  static Color get surface => isDark ? darkSurface : lightSurface;
  static Color get surfaceTranslucent => isDark ? const Color(0xFA141222) : const Color(0xFAFFFFFF);
  static Color get background => isDark ? darkBackground : lightBackground;
  static Color get backgroundTop => isDark ? const Color(0xFF141222) : const Color(0xFFFAF9FD);
  static Color get backgroundBottom => isDark ? const Color(0xFF0A0910) : const Color(0xFFEEEBF7);
  static Color get card => isDark ? darkCard : lightCard;
  static Color get elevated => isDark ? darkElevated : lightElevated;
  static Color get elevatedHover => isDark ? darkElevatedHover : lightElevatedHover;

  static Color get textPrimary => isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textSubtle => isDark ? darkTextSubtle : lightTextSubtle;
  static Color get textLight => Colors.white;

  // Backward compatibility aliases
  static Color get black => background;
  static Color get dark => surface;

  // Dynamic Gradients
  static LinearGradient get backgroundGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141222), Color(0xFF0A0910)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF9FD), Color(0xFFEEEBF7)],
        );

  static const LinearGradient sunriseGradient = LinearGradient(
    begin: Alignment(-0.8, -0.6),
    end: Alignment(0.9, 0.8),
    colors: [
      Color(0xFF2D1A60),
      Color(0xFF7E2B88),
      Color(0xFFD44E7E),
      Color(0xFFEA8468),
    ],
  );

  static LinearGradient get nowPlayingGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF282239),
            Color(0xFF1E1A2C),
            Color(0xFF141320),
            Color(0xFF0D0C15),
          ],
          stops: [0.04, 0.36, 0.74, 1.0],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB5ACC7),
            Color(0xFF8F87B0),
            Color(0xFF383E6A),
            Color(0xFF1B2750),
          ],
          stops: [0.04, 0.36, 0.74, 1.0],
        );

  static LinearGradient get miniPlayerGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFA27223A),
            Color(0xF51C1A2D),
          ],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xF06C5C7E),
            Color(0xE54B4A6C),
          ],
        );

  static LinearGradient get bottomNavGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xF21B192B),
            Color(0xF8141223),
          ],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xF5FCFBFE),
            Color(0xF2F3F1FA),
          ],
        );

  static const LinearGradient likedSongsGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFF5231A8),
      Color(0xFF8660EB),
    ],
  );

  static const LinearGradient activePillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7A69E6),
      Color(0xFF8C7BF6),
    ],
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: (isDark ? Colors.black : const Color(0xFF63567D)).withOpacity(isDark ? 0.4 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ];

  static List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: (isDark ? Colors.black : const Color(0xFF52446A)).withOpacity(isDark ? 0.55 : 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

class DecibelTypography {
  static const String headingFont = 'Outfit';
  static const String bodyFont = 'Plus Jakarta Sans';

  static TextStyle get greetingTitle => TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: DecibelColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get screenTitle => TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w600,
        fontSize: 24,
        color: DecibelColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get sectionHeading => TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: DecibelColors.textPrimary,
      );

  static TextStyle get seeAll => TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w500,
        fontSize: 10,
        color: DecibelColors.textSecondary,
      );

  static const TextStyle heroTitle = TextStyle(
    fontFamily: headingFont,
    fontWeight: FontWeight.w600,
    fontSize: 25,
    color: Colors.white,
    height: 1.05,
    letterSpacing: -0.3,
  );

  static const TextStyle heroArtist = TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.normal,
    fontSize: 14,
    color: Colors.white,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: bodyFont,
    fontWeight: FontWeight.w700,
    fontSize: 8.5,
    letterSpacing: 1.4,
    color: Colors.white70,
  );

  static TextStyle get cardTitle => TextStyle(
        fontFamily: headingFont,
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
        color: DecibelColors.textPrimary,
      );

  static TextStyle get bodyMuted => TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.normal,
        fontSize: 10,
        color: DecibelColors.textSecondary,
      );
}
