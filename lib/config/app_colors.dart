import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// NOAI COLOR TOKENS
/// WEB = SINGLE SOURCE OF TRUTH
/// ─────────────────────────────────────────────────────────────
///
/// Design system rules:
/// • Dark-first (web matches)
/// • Navy backgrounds (not pure black)
/// • Flat surfaces (no gradients on cards)
/// • Subtle borders
/// • Single accent color (emerald)
///
/// ❗ Never use raw colors in UI
/// ❗ Always read from Theme.of(context).colorScheme
///
class AppColors {
  /* ───────────────── BRAND ───────────────── */

  /// Primary NOAI accent (CTA, verified, trust score)
  static const Color primary = Color(0xFF22C55E); // Emerald-500

  /// Soft primary background (badges, chips)
  static const Color primarySoft = Color.fromRGBO(34, 197, 94, 0.15);

  /* ───────────────── DARK THEME (PRIMARY) ───────────────── */

  /// App background (deep navy)
  static const Color backgroundDark = Color(0xFF0B1220);

  /// Main surface (feed cards, lists)
  static const Color surfaceDark = Color(0xFF111A2E);

  /// Elevated surface (app bar, menus, dropdowns)
  static const Color surfaceVariantDark = Color(0xFF16233A);

  /// Card background
  static const Color cardDark = surfaceDark;

  /// Borders & dividers
  static const Color outlineDark = Color.fromRGBO(255, 255, 255, 0.06);

  static const Color outlineVariantDark = Color.fromRGBO(255, 255, 255, 0.04);

  /* ───────────────── TEXT (DARK) ───────────────── */

  static const Color textPrimaryDark = Color(0xFFE5E7EB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textMutedDark = Color(0xFF6B7280);

  /* ───────────────── LIGHT THEME (OPTIONAL) ───────────────── */

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color outlineLight = Color(0xFFE2E8F0);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  /* ───────────────── FEEDBACK ───────────────── */

  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF38BDF8);

  /* ───────────────── MISC ───────────────── */

  static const Color verified = success;
  static const Color like = error;

  /// Primary gradient (for hero elements, cards)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Trust score gradient (for trust score indicators)
  static const LinearGradient trustScoreGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF38BDF8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Verified badge gradient (for human verification badges)
  static const LinearGradient verifiedBadgeGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF10B981)],
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

  primary: AppColors.primary,
  onPrimary: Colors.black,

  secondary: AppColors.primary,
  onSecondary: Colors.black,

  background: AppColors.backgroundDark,
  onBackground: AppColors.textPrimaryDark,

  surface: AppColors.surfaceDark,
  onSurface: AppColors.textPrimaryDark,

  surfaceVariant: AppColors.surfaceVariantDark,
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
  onPrimary: Colors.white,

  secondary: AppColors.primary,
  onSecondary: Colors.white,

  background: AppColors.backgroundLight,
  onBackground: AppColors.textPrimaryLight,

  surface: AppColors.surfaceLight,
  onSurface: AppColors.textPrimaryLight,

  surfaceVariant: AppColors.surfaceVariantLight,
  onSurfaceVariant: AppColors.textSecondaryLight,

  outline: AppColors.outlineLight,
  outlineVariant: AppColors.outlineLight,

  error: AppColors.error,
  onError: Colors.white,

  tertiary: AppColors.info,
  onTertiary: Colors.white,
);
