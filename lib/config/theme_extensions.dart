import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../utils/responsive_utils.dart';

/// Extension to easily access theme-aware colors and responsive utilities
extension ThemeExtension on BuildContext {
  /// Returns true if the current theme is dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Returns the appropriate background color for the current theme
  Color get backgroundColor =>
      isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;

  /// Returns the appropriate surface color for the current theme
  Color get surfaceColor =>
      isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;

  /// Returns the appropriate outline color for the current theme
  Color get borderColor =>
      isDarkMode ? AppColors.outlineDark : AppColors.outlineLight;

  /// Returns the appropriate primary text color for the current theme
  Color get textPrimaryColor =>
      isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  /// Returns the appropriate secondary text color for the current theme
  Color get textSecondaryColor =>
      isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  /// Returns the primary gradient for cards and hero elements
  LinearGradient get cardGradient => AppColors.primaryGradient;

  /// Quick access to theme
  ThemeData get theme => Theme.of(this);

  /// Quick access to text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Quick access to color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // ─────────────────────────────────────────────────────────────────────────
  // RESPONSIVE UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Get the screen size category (small, medium, large)
  ScreenSize get screenSizeCategory => ResponsiveUtils.screenSize(this);

  /// Check if screen is compact (small phones)
  bool get isCompactScreen => ResponsiveUtils.isCompact(this);

  /// Check if screen is large
  bool get isLargeScreen => ResponsiveUtils.isLarge(this);

  /// Get the scaling factor for this screen
  double get responsiveScale => ResponsiveUtils.scaleFactor(this);

  /// Scale a value based on screen width
  double responsive(double value, {double? min, double? max}) {
    return ResponsiveUtils.scale(this, value, min: min, max: max);
  }

  /// Scale a text value (dampened for readability)
  double responsiveText(double value) {
    return ResponsiveUtils.scaleText(this, value);
  }

  /// Get screen width
  double get screenWidth => ResponsiveUtils.screenWidth(this);

  /// Get screen height
  double get screenHeight => ResponsiveUtils.screenHeight(this);

  /// Get minimum touch target size
  double get minTouchTarget => ResponsiveUtils.minTouchTarget(this);
}
