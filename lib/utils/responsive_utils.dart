import 'package:flutter/material.dart';

/// Screen size categories for mobile devices
enum ScreenSize { small, medium, large }

/// Responsive utility class for screen-aware sizing.
///
/// This utility provides scaling factors and screen size detection
/// to enable responsive layouts across different mobile screen sizes.
///
/// Usage:
/// ```dart
/// final factor = ResponsiveUtils.scaleFactor(context);
/// final scaledPadding = ResponsiveUtils.scale(context, 16.0);
/// final scaledFontSize = ResponsiveUtils.scaleText(context, 14.0);
/// ```
class ResponsiveUtils {
  ResponsiveUtils._(); // Private constructor to prevent instantiation

  /// Design reference width (standard iPhone width - 375px)
  static const double designWidth = 375.0;

  /// Breakpoints for mobile screens
  static const double smallBreakpoint = 360.0;   // iPhone SE, small Android
  static const double mediumBreakpoint = 414.0;  // iPhone Pro, standard Android

  /// Scaling factor limits to prevent extreme scaling
  static const double _minScale = 0.85;  // Floor for small screens
  static const double _maxScale = 1.15;  // Ceiling for large screens

  /// Dampening factor for text scaling (prevents text from getting too large/small)
  static const double _textDampeningFactor = 0.6;

  /// Get the current screen size category
  static ScreenSize screenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallBreakpoint) return ScreenSize.small;
    if (width < mediumBreakpoint) return ScreenSize.medium;
    return ScreenSize.large;
  }

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Calculate the scaling factor based on screen width.
  /// Returns a value between [_minScale] and [_maxScale].
  static double scaleFactor(BuildContext context) {
    final width = screenWidth(context);
    final scale = width / designWidth;
    return scale.clamp(_minScale, _maxScale);
  }

  /// Scale a value based on screen width with optional min/max bounds.
  ///
  /// [value] - The base value to scale
  /// [min] - Optional minimum value (floor)
  /// [max] - Optional maximum value (ceiling)
  static double scale(
    BuildContext context,
    double value, {
    double? min,
    double? max,
  }) {
    final scaled = value * scaleFactor(context);
    if (min != null && max != null) {
      return scaled.clamp(min, max);
    }
    if (min != null) return scaled < min ? min : scaled;
    if (max != null) return scaled > max ? max : scaled;
    return scaled;
  }

  /// Scale for text with dampened factor to prevent text getting too large/small.
  /// Text scaling is more conservative than general scaling to maintain readability.
  ///
  /// [value] - The base font size to scale
  static double scaleText(BuildContext context, double value) {
    final factor = scaleFactor(context);
    // Dampen the text scaling (move only 60% toward full scale)
    final dampenedFactor = 1.0 + (factor - 1.0) * _textDampeningFactor;
    // Ensure minimum readable size of 10px and maximum of 110% original
    return (value * dampenedFactor).clamp(value * 0.85, value * 1.1);
  }

  /// Get responsive padding based on screen size.
  static EdgeInsets responsivePadding(
    BuildContext context, {
    double horizontal = 16.0,
    double vertical = 8.0,
  }) {
    final factor = scaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal * factor,
      vertical: vertical * factor,
    );
  }

  /// Get responsive symmetric padding.
  static EdgeInsets responsiveSymmetricPadding(
    BuildContext context, {
    double? horizontal,
    double? vertical,
  }) {
    final factor = scaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: (horizontal ?? 0) * factor,
      vertical: (vertical ?? 0) * factor,
    );
  }

  /// Get responsive EdgeInsets.all
  static EdgeInsets responsiveAllPadding(BuildContext context, double value) {
    return EdgeInsets.all(scale(context, value));
  }

  /// Get responsive EdgeInsets.fromLTRB
  static EdgeInsets responsiveLTRBPadding(
    BuildContext context,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final factor = scaleFactor(context);
    return EdgeInsets.fromLTRB(
      left * factor,
      top * factor,
      right * factor,
      bottom * factor,
    );
  }

  /// Check if screen is compact (for layout decisions)
  static bool isCompact(BuildContext context) {
    return screenSize(context) == ScreenSize.small;
  }

  /// Check if screen is large
  static bool isLarge(BuildContext context) {
    return screenSize(context) == ScreenSize.large;
  }

  /// Minimum touch target size (44px on small screens, 48px otherwise)
  /// Following iOS Human Interface Guidelines and Material Design specs
  static double minTouchTarget(BuildContext context) {
    final size = screenSize(context);
    return size == ScreenSize.small ? 44.0 : 48.0;
  }

  /// Get responsive border radius
  static BorderRadius responsiveBorderRadius(
    BuildContext context,
    double radius,
  ) {
    return BorderRadius.circular(scale(context, radius));
  }

  /// Get responsive circular border radius
  static Radius responsiveRadius(BuildContext context, double radius) {
    return Radius.circular(scale(context, radius));
  }

  /// Calculate percentage of screen width
  static double widthPercent(BuildContext context, double percent) {
    return screenWidth(context) * (percent / 100);
  }

  /// Calculate percentage of screen height
  static double heightPercent(BuildContext context, double percent) {
    return screenHeight(context) * (percent / 100);
  }

  /// Get the safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get available height (screen height minus safe areas)
  static double availableHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height -
           mediaQuery.padding.top -
           mediaQuery.padding.bottom;
  }

  /// Get available width (screen width minus safe areas)
  static double availableWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width -
           mediaQuery.padding.left -
           mediaQuery.padding.right;
  }
}
