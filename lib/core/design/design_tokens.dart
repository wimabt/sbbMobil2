import 'package:flutter/material.dart';

/// Design tokens for consistent spacing, sizing, and styling across the app
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Border radius tokens
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0; // Featured cards - high-fidelity design
  static const double xxl = 24.0;
  static const double pill = 999.0; // For pills and chips
}

/// Elevation/shadow tokens - Light theme: soft, diffuse shadows
class AppElevation {
  AppElevation._();

  /// Very subtle shadow for cards
  static final List<BoxShadow> level1 = [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  /// Soft diffuse shadow for floating elements
  static final List<BoxShadow> level2 = [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  /// Medium shadow for elevated cards
  static final List<BoxShadow> level3 = [
        BoxShadow(
          color: Colors.black.withAlpha(12),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];

  /// Strong shadow for floating action buttons
  static final List<BoxShadow> level4 = [
        BoxShadow(
          color: Colors.black.withAlpha(15),
          blurRadius: 32,
          spreadRadius: 0,
          offset: const Offset(0, 12),
        ),
      ];

  /// Soft floating shadow for quick action buttons (light theme)
  static final List<BoxShadow> floatingButton = [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withAlpha(5),
          blurRadius: 6,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  /// Featured card shadow - very soft and diffuse
  static final List<BoxShadow> featuredCard = [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Dark theme specific effects
class AppDarkEffects {
  AppDarkEffects._();

  /// Neon glow effect for dark theme cards - subtle and gentle
  static List<BoxShadow> neonGlow(Color color) => [
        BoxShadow(
          color: color.withAlpha(20),
          blurRadius: 12,
          spreadRadius: -1,
          offset: const Offset(0, 0),
        ),
        BoxShadow(
          color: color.withAlpha(10),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  /// Subtle border for dark cards
  static BoxBorder subtleBorder(BuildContext context) => Border.all(
        color: Colors.white.withAlpha(15),
        width: 1,
      );

  /// Inner glow gradient for dark cards
  static BoxDecoration cardDecoration({
    Color? backgroundColor,
    double borderRadius = AppRadius.xl,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(borderRadius),
      border: withBorder
          ? Border.all(
              color: Colors.white.withAlpha(10),
              width: 1,
            )
          : null,
    );
  }

  /// Glassmorphism effect for dark theme buttons
  static BoxDecoration glassmorphism({
    double borderRadius = AppRadius.pill,
    Color? tintColor,
  }) {
    return BoxDecoration(
      color: (tintColor ?? Colors.white).withAlpha(10),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withAlpha(15),
        width: 1,
      ),
    );
  }
}

/// Touch target minimum sizes (accessibility)
class AppTouchTarget {
  AppTouchTarget._();

  static const double minimum = 48.0; // WCAG AA compliance
  static const double comfortable = 56.0; // Better UX
}

/// Bottom navigation constants
class AppNavBar {
  AppNavBar._();

  static const double height = 64.0;
  static const double fabSize = 64.0;

  /// Bottom padding to prevent content from hiding behind the navbar
  /// Use this in list screens with extendBody: true
  static const double bottomPadding = 80.0; // navbar height + extra spacing
  
  // Compact mode for map screen
  static const double compactHeight = 48.0;
  static const double compactFabSize = 48.0;
  static const double compactBottomPadding = 56.0;
}

/// Custom color tokens for semantic colors and theme-specific colors
class AppColors {
  AppColors._();

  // === Light Theme Colors ===

  /// Marka — koyu çam yeşili (üst bar, birincil aksan, başlıklar)
  static const Color brandGreen = Color(0xFF004D26);

  /// Marka — orta ton (gradyan, ikincil vurgu)
  static const Color brandGreenMid = Color(0xFF0D6E3F);

  /// Marka — daha açık yeşil (ikon halkaları, küçük vurgular)
  static const Color brandGreenBright = Color(0xFF2E8B57);

  /// Çok açık yeşil zemin (chip, kart tint)
  static const Color brandGreenTint = Color(0xFFE8F2EC);

  /// Light theme background — soğuk off-white / çok açık mavi-gri
  static const Color lightBackground = Color(0xFFF4F8FB);

  /// Light theme card background - pure white
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light theme marka gradyan uçları
  static const Color lightGradientStart = Color(0xFF0D7A4F);
  static const Color lightGradientEnd = Color(0xFF004D26);

  /// Light theme accent colors for quick actions (marka ile uyumlu)
  static const Color accentMap = Color(0xFF004D26);
  static const Color accentFood = Color(0xFFEF6C00);
  static const Color accentRoutes = Color(0xFF006B5C);
  static const Color accentCulture = Color(0xFF8E24AA);

  // === Dark Theme Colors ===
  
  /// Dark theme background - deep matte charcoal
  static const Color darkBackground = Color(0xFF121212);
  
  /// Dark theme card background - slightly lighter dark grey
  static const Color darkSurface = Color(0xFF1E1E1E);
  
  /// Dark theme elevated surface
  static const Color darkSurfaceElevated = Color(0xFF252525);
  
  /// Premium accent colors for dark theme (Professional Night Mode)
  /// Designed for government/municipality apps - vivid but easy on eyes
  static const Color neonBlue = Color(0xFF00B0FF);     // Smart Ocean Blue - primary accent (Light Blue 400)
  static const Color neonPurple = Color(0xFF9575CD);   // Muted Purple - softer 
  static const Color neonCyan = Color(0xFF26A69A);     // Sophisticated Teal 400 - secondary accent
  static const Color neonPink = Color(0xFFE91E63);     // Material Pink - professional
  static const Color neonOrange = Color(0xFFFFB74D);   // Warm Amber - ratings

  // === Semantic Colors ===
  
  // Success (green) - for ratings, completed states
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF388E3C);

  // Warning (orange) - for badges, levels
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);

  // Error (red) - for errors, new badges
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);

  // Info (teal) - for events, info badges
  static const Color info = Color(0xFF009688);
  static const Color infoLight = Color(0xFF4DB6AC);
  static const Color infoDark = Color(0xFF00796B);

  // === Primary Brand Colors (from AI_RULES.md) ===
  
  /// Ocean Teal - legacy secondary accent
  static const Color oceanTeal = Color(0xFF26A69A);
  
  /// Royal Blue - Alternative primary color
  static const Color royalBlue = Color(0xFF1976D2);

  // === Card Surface Colors ===
  
  /// Light theme card surface
  static const Color cardSurfaceLight = Color(0xFFFFFFFF);
  
  /// Dark theme card surface
  static const Color cardSurfaceDark = Color(0xFF1E1E1E);

  // === Text Colors ===
  
  /// Light theme primary text
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  
  /// Light theme secondary text
  static const Color textSecondaryLight = Color(0xFF6B7280);
  
  /// Dark theme primary text
  static const Color textPrimaryDark = Color(0xFFEEEEEE);
  
  /// Dark theme secondary text
  static const Color textSecondaryDark = Color(0xFFB0BEC5);
}

/// Gradient definitions
class AppGradients {
  AppGradients._();

  /// Marka yeşili gradyan — açık tema puan kartı vb.
  static const LinearGradient lightBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D7A4F),
      Color(0xFF004D26),
    ],
  );

  /// Koyu tema puan kartı — koyu yeşil tonları
  static const LinearGradient darkNeonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B5E20),
      Color(0xFF002818),
    ],
  );

  /// Hero overlay gradient for text readability (light theme)
  static const LinearGradient heroOverlayLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x40000000),
      Color(0xCC000000),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Hero overlay gradient for dark/night images
  static const LinearGradient heroOverlayDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x60000000),
      Color(0xE6000000),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  /// Glassmorphism gradient overlay
  static LinearGradient glassmorphismGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withAlpha(15),
      Colors.white.withAlpha(5),
    ],
  );
}

/// Typography scale helpers
class AppTextStyles {
  AppTextStyles._();

  /// Small label text (11-12px)
  static TextStyle? labelSmall(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall;

  /// Body small text (12-14px)
  static TextStyle? bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall;

  /// Body medium text (14-16px)
  static TextStyle? bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;

  /// Title small (16-18px)
  static TextStyle? titleSmall(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall;

  /// Title medium (18-20px)
  static TextStyle? titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  /// Title large (20-22px)
  static TextStyle? titleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  /// Headline small (24px)
  static TextStyle? headlineSmall(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall;
}
