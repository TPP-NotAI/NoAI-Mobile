import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension to easily access theme-aware colors throughout the app
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
}
