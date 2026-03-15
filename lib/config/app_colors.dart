import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// ROOVERSE COLOR TOKENS
/// SOURCE: Rooverse Brand Style Guide (official)
/// ─────────────────────────────────────────────────────────────
///
/// Official palette (Rooverse Brand Style Guide):
///   Primary   #1E1E21  — Near-black   → scaffold background (dark mode)
///   Gold      #DEA331  — Brand Gold   → CTAs, active states, icons, logo
///   Accent    #333333  — Dark grey    → elevated surfaces, cards (dark mode)
///   Base      #EEEDE8  — Warm off-white → primary text on dark, light bg
///
/// ❗ Never use raw colors in UI
/// ❗ Always read from Theme.of(context).colorScheme
///
class AppColors {
  /* ───────────────── BRAND (OFFICIAL) ───────────────── */

  /// Primary brand colour — #1E1E21 near-black (scaffold, dark bg)
  static const Color brandPrimary = Color(0xFF1E1E21);

  /// Gold accent — #DEA331 (CTAs, active states, icons, logo)
  /// Used as colorScheme.primary throughout the app
  static const Color primary = Color(0xFFDEA331);

  /// Darker gold for pressed/hover states
  static const Color primaryDark = Color(0xFFBB8620);

  /// Soft gold background (badges, chips, highlights)
  static const Color primarySoft = Color.fromRGBO(222, 163, 49, 0.15);

  /* ───────────────── DARK THEME ───────────────── */

  /// App background / surface — Primary brand colour (#1E1E21)
  /// Used as colorScheme.surface (M3 scaffold/dialog base)
  static const Color backgroundDark = Color(0xFF1E1E21);

  /// Cards / elevated containers — Accent brand colour (#333333)
  static const Color surfaceDark = Color(0xFF333333);

  /// Inputs / chips — mid level (#26262A)
  static const Color surfaceVariantDark = Color(0xFF26262A);

  /// Card background (same as surface)
  static const Color cardDark = surfaceDark;

  /// Borders & dividers
  static const Color outlineDark = Color.fromRGBO(255, 255, 255, 0.10);
  static const Color outlineVariantDark = Color.fromRGBO(255, 255, 255, 0.06);

  /* ───────────────── TEXT (DARK) ───────────────── */

  /// Base brand color — warm off-white (#EEEDE8)
  static const Color textPrimaryDark = Color(0xFFEEEDE8);

  /// Secondary text — muted warm grey
  static const Color textSecondaryDark = Color(0xFF9E9A94);

  /// Muted / placeholder text
  static const Color textMutedDark = Color(0xFF6B6864);

  /* ───────────────── LIGHT THEME ───────────────── */

  /// Light background — warm off-white base
  static const Color backgroundLight = Color(0xFFEEEDE8);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE8E6E0);
  static const Color outlineLight = Color(0xFFD4D0C8);

  /// Primary text on light — Secondary brand color
  static const Color textPrimaryLight = Color(0xFF1E1E21);

  /// Secondary text on light — Accent brand color
  static const Color textSecondaryLight = Color(0xFF333333);

  /* ───────────────── FEEDBACK ───────────────── */

  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF38BDF8);

  /* ───────────────── MISC ───────────────── */

  static const Color verified = primary;
  static const Color like = error;

  /// Gold gradient — hero elements, CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFDEA331), Color(0xFFF0C060)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Trust score gradient
  static const LinearGradient trustScoreGradient = LinearGradient(
    colors: [Color(0xFFDEA331), Color(0xFFF0C060)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Verified badge gradient
  static const LinearGradient verifiedBadgeGradient = LinearGradient(
    colors: [Color(0xFFDEA331), Color(0xFFBB8620)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// ─────────────────────────────────────────────────────────────
/// MATERIAL 3 COLOR SCHEMES
/// USED BY ThemeProvider
/// ─────────────────────────────────────────────────────────────

const ColorScheme noaiDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  // Gold (#DEA331) — CTAs, active icons, selection indicators
  primary: AppColors.primary,
  onPrimary: Colors.black,
  secondary: AppColors.primary,
  onSecondary: Colors.black,
  // Primary (#1E1E21) — M3 surface = scaffold/page base
  surface: AppColors.backgroundDark,
  onSurface: AppColors.textPrimaryDark,
  // Accent (#333333) — cards, elevated containers
  surfaceContainer: AppColors.surfaceDark,
  surfaceContainerHigh: AppColors.surfaceDark,
  // Mid-level (#26262A) — inputs, chips
  surfaceContainerHighest: AppColors.surfaceVariantDark,
  onSurfaceVariant: AppColors.textSecondaryDark,
  outline: AppColors.outlineDark,
  outlineVariant: AppColors.outlineVariantDark,
  error: AppColors.error,
  onError: Colors.white,
  tertiary: AppColors.info,
  onTertiary: Colors.white,
);

const ColorScheme noaiLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: Colors.black,
  secondary: AppColors.primary,
  onSecondary: Colors.black,
  surface: AppColors.backgroundLight,
  onSurface: AppColors.textPrimaryLight,
  surfaceContainer: AppColors.surfaceLight,
  surfaceContainerHigh: AppColors.surfaceLight,
  surfaceContainerHighest: AppColors.surfaceVariantLight,
  onSurfaceVariant: AppColors.textSecondaryLight,
  outline: AppColors.outlineLight,
  outlineVariant: AppColors.outlineLight,
  error: AppColors.error,
  onError: Colors.white,
  tertiary: AppColors.info,
  onTertiary: Colors.white,
);
