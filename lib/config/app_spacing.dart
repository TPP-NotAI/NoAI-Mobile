import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Spacing system matching web application specs
/// Base unit: 1rem = 16px
///
/// For responsive values, use the extension methods:
/// ```dart
/// AppSpacing.largePlus.responsive(context)
/// ```
class AppSpacing {
  // Padding values
  static const double tiny = 3.2; // 0.2rem
  static const double extraSmall = 4.0; // 0.25rem
  static const double small = 6.4; // 0.4rem
  static const double mediumSmall = 8.0; // 0.5rem
  static const double medium = 9.6; // 0.6em
  static const double standard = 12.0; // 0.75rem
  static const double mediumLarge = 12.8; // 0.8rem
  static const double large = 14.0; // 0.875rem
  static const double largePlus = 16.0; // 1rem
  static const double extraLarge = 19.2; // 1.2em
  static const double double_ = 24.0; // 1.5rem
  static const double triple = 32.0; // 2rem
  static const double largeTriple = 40.0; // 2.5rem

  // Border Radius values
  static const double radiusSmall = 8.0; // 8px
  static const double radiusMedium = 10.0; // 10px
  static const double radiusLarge = 12.0; // 12px
  static const double radiusExtraLarge = 16.0; // 16px
  static const double radiusModal = 20.0; // 20px
  static const double radiusPill = 50.0; // 50px
  static const double radiusCircle = 9999.0; // Full circle

  // Shadow elevations (matching web box-shadow values)
  static const double shadowSubtle = 1.0;
  static const double shadowSmall = 4.0;
  static const double shadowMedium = 10.0;
  static const double shadowLarge = 10.0;
  static const double shadowExtraLarge = 20.0;

  // ─────────────────────────────────────────────────────────────────────────
  // RESPONSIVE HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get a responsive value scaled to screen size
  static double responsiveValue(BuildContext context, double value) {
    return ResponsiveUtils.scale(context, value);
  }

  /// Get responsive padding with all sides equal
  static EdgeInsets responsiveAll(BuildContext context, double value) {
    return EdgeInsets.all(ResponsiveUtils.scale(context, value));
  }

  /// Get responsive symmetric padding
  static EdgeInsets responsiveSymmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    final factor = ResponsiveUtils.scaleFactor(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal * factor,
      vertical: vertical * factor,
    );
  }

  /// Get responsive LTRB padding
  static EdgeInsets responsiveLTRB(
    BuildContext context,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final factor = ResponsiveUtils.scaleFactor(context);
    return EdgeInsets.fromLTRB(
      left * factor,
      top * factor,
      right * factor,
      bottom * factor,
    );
  }

  /// Get responsive only padding
  static EdgeInsets responsiveOnly(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    final factor = ResponsiveUtils.scaleFactor(context);
    return EdgeInsets.only(
      left: left * factor,
      top: top * factor,
      right: right * factor,
      bottom: bottom * factor,
    );
  }

  /// Get responsive border radius
  static BorderRadius responsiveRadius(BuildContext context, double radius) {
    return BorderRadius.circular(ResponsiveUtils.scale(context, radius));
  }

  /// Get responsive circular radius
  static Radius responsiveCircular(BuildContext context, double radius) {
    return Radius.circular(ResponsiveUtils.scale(context, radius));
  }
}
