import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Extension on num to provide responsive scaling.
///
/// Usage:
/// ```dart
/// // Scale a padding value
/// padding: EdgeInsets.all(16.responsive(context))
///
/// // Scale with min/max bounds
/// height: 100.responsive(context, min: 80, max: 120)
///
/// // Scale font size (dampened for readability)
/// fontSize: 14.responsiveText(context)
/// ```
extension ResponsiveNum on num {
  /// Scale this value based on screen width.
  ///
  /// [context] - BuildContext for MediaQuery access
  /// [min] - Optional minimum value (floor)
  /// [max] - Optional maximum value (ceiling)
  double responsive(BuildContext context, {double? min, double? max}) {
    return ResponsiveUtils.scale(context, toDouble(), min: min, max: max);
  }

  /// Scale this value for text (dampened scaling for readability).
  double responsiveText(BuildContext context) {
    return ResponsiveUtils.scaleText(context, toDouble());
  }

  /// Convenience getter for screen-width percentage.
  ///
  /// Example: `50.sw(context)` returns 50% of screen width
  double sw(BuildContext context) {
    return ResponsiveUtils.screenWidth(context) * (toDouble() / 100);
  }

  /// Convenience getter for screen-height percentage.
  ///
  /// Example: `50.sh(context)` returns 50% of screen height
  double sh(BuildContext context) {
    return ResponsiveUtils.screenHeight(context) * (toDouble() / 100);
  }
}

/// Extension on BuildContext for quick responsive access.
///
/// Usage:
/// ```dart
/// if (context.isCompact) {
///   // Use compact layout
/// }
///
/// final scale = context.scaleFactor;
/// ```
extension ResponsiveContext on BuildContext {
  /// Get screen size category (small, medium, large)
  ScreenSize get screenSize => ResponsiveUtils.screenSize(this);

  /// Get scaling factor for this screen
  double get scaleFactor => ResponsiveUtils.scaleFactor(this);

  /// Check if compact screen (small phones)
  bool get isCompact => ResponsiveUtils.isCompact(this);

  /// Check if large screen
  bool get isLarge => ResponsiveUtils.isLarge(this);

  /// Get screen width
  double get screenWidth => ResponsiveUtils.screenWidth(this);

  /// Get screen height
  double get screenHeight => ResponsiveUtils.screenHeight(this);

  /// Get available height (minus safe areas)
  double get availableHeight => ResponsiveUtils.availableHeight(this);

  /// Get available width (minus safe areas)
  double get availableWidth => ResponsiveUtils.availableWidth(this);

  /// Get minimum touch target size
  double get minTouchTarget => ResponsiveUtils.minTouchTarget(this);

  /// Scale a value based on screen width
  double responsive(double value, {double? min, double? max}) {
    return ResponsiveUtils.scale(this, value, min: min, max: max);
  }

  /// Scale a text value (dampened)
  double responsiveText(double value) {
    return ResponsiveUtils.scaleText(this, value);
  }

  /// Get responsive symmetric padding
  EdgeInsets responsivePadding({
    double horizontal = 16.0,
    double vertical = 8.0,
  }) {
    return ResponsiveUtils.responsivePadding(
      this,
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  /// Get responsive all-sides padding
  EdgeInsets responsiveAllPadding(double value) {
    return ResponsiveUtils.responsiveAllPadding(this, value);
  }

  /// Get responsive LTRB padding
  EdgeInsets responsiveLTRBPadding(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return ResponsiveUtils.responsiveLTRBPadding(this, left, top, right, bottom);
  }

  /// Get responsive border radius
  BorderRadius responsiveBorderRadius(double radius) {
    return ResponsiveUtils.responsiveBorderRadius(this, radius);
  }
}

/// Extension on EdgeInsets for responsive padding.
///
/// Usage:
/// ```dart
/// padding: const EdgeInsets.all(16).responsive(context)
/// ```
extension ResponsiveEdgeInsets on EdgeInsets {
  /// Create responsive EdgeInsets by scaling all values
  EdgeInsets responsive(BuildContext context) {
    final factor = ResponsiveUtils.scaleFactor(context);
    return EdgeInsets.fromLTRB(
      left * factor,
      top * factor,
      right * factor,
      bottom * factor,
    );
  }
}

/// Extension on TextStyle for responsive text.
///
/// Usage:
/// ```dart
/// style: TextStyle(fontSize: 14).responsive(context)
/// ```
extension ResponsiveTextStyle on TextStyle {
  /// Create responsive TextStyle with scaled font size
  TextStyle responsive(BuildContext context) {
    if (fontSize == null) return this;
    return copyWith(
      fontSize: ResponsiveUtils.scaleText(context, fontSize!),
    );
  }

  /// Create responsive TextStyle with fully scaled font size (not dampened)
  TextStyle responsiveFull(BuildContext context) {
    if (fontSize == null) return this;
    return copyWith(
      fontSize: ResponsiveUtils.scale(context, fontSize!),
    );
  }
}

/// Extension on BorderRadius for responsive corners.
///
/// Usage:
/// ```dart
/// borderRadius: BorderRadius.circular(12).responsive(context)
/// ```
extension ResponsiveBorderRadius on BorderRadius {
  /// Create responsive BorderRadius by scaling all radii
  BorderRadius responsive(BuildContext context) {
    final factor = ResponsiveUtils.scaleFactor(context);
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft.x * factor),
      topRight: Radius.circular(topRight.x * factor),
      bottomLeft: Radius.circular(bottomLeft.x * factor),
      bottomRight: Radius.circular(bottomRight.x * factor),
    );
  }
}

/// Extension on SizedBox for responsive spacing.
///
/// Helper to create responsive SizedBox widgets.
extension ResponsiveSizedBox on SizedBox {
  /// Create a responsive SizedBox
  static SizedBox responsive(
    BuildContext context, {
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width != null ? ResponsiveUtils.scale(context, width) : null,
      height: height != null ? ResponsiveUtils.scale(context, height) : null,
    );
  }

  /// Create a responsive horizontal spacer
  static SizedBox horizontalSpace(BuildContext context, double width) {
    return SizedBox(width: ResponsiveUtils.scale(context, width));
  }

  /// Create a responsive vertical spacer
  static SizedBox verticalSpace(BuildContext context, double height) {
    return SizedBox(height: ResponsiveUtils.scale(context, height));
  }
}

/// Extension on BoxConstraints for responsive constraints.
extension ResponsiveBoxConstraints on BoxConstraints {
  /// Create responsive BoxConstraints by scaling all values
  BoxConstraints responsive(BuildContext context) {
    final factor = ResponsiveUtils.scaleFactor(context);
    return BoxConstraints(
      minWidth: minWidth * factor,
      maxWidth: maxWidth.isFinite ? maxWidth * factor : maxWidth,
      minHeight: minHeight * factor,
      maxHeight: maxHeight.isFinite ? maxHeight * factor : maxHeight,
    );
  }
}
