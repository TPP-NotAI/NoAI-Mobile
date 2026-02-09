import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Typography system matching web application specs
/// Base font: system-ui, Avenir, Helvetica, Arial, sans-serif
///
/// For responsive font sizes, use:
/// ```dart
/// fontSize: AppTypography.responsiveFontSize(context, AppTypography.base)
/// ```
/// Or with TextStyles:
/// ```dart
/// style: AppTypography.responsiveStyle(context, AppTypography.postContent)
/// ```
class AppTypography {
  // Font Sizes (matching web rem values, 1rem = 16px)
  static const double extraLargeHeading = 51.2; // 3.2em
  static const double largeHeading = 40.0; // 2.5rem
  static const double sectionHeading = 32.0; // 2rem
  static const double large = 28.0; // 1.75rem
  static const double mediumHeading = 24.0; // 1.5rem
  static const double subheading = 20.8; // 1.3rem
  static const double cardHeading = 19.2; // 1.2rem
  static const double smallHeading = 17.6; // 1.1rem
  static const double base = 16.0; // 1rem
  static const double mediumText = 15.2; // 0.95rem
  static const double small = 14.4; // 0.9rem
  static const double extraSmall = 13.6; // 0.85rem
  static const double tiny = 12.8; // 0.8rem
  static const double badgeText = 12.0; // 0.75rem

  // Icon Sizes
  static const double tinyIcon = 11.2; // 0.7rem
  static const double smallIcon = 17.6; // 1.1rem
  static const double mediumIcon = 19.2; // 1.2rem
  static const double largeIcon = 20.8; // 1.3rem
  static const double extraLargeIcon = 24.0; // 1.5rem
  static const double logoShield = 28.8; // 1.8rem
  static const double authShield = 40.0; // 2.5rem
  static const double modalClose = 32.0; // 2rem
  static const double walletBalance = 32.0; // 2rem

  // Font Weights
  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Line Heights
  static const double defaultLineHeight = 1.5;
  static const double tightLineHeight = 1.1;
  static const double relaxedLineHeight = 1.7;

  // Text Styles matching web components

  // Auth page heading
  static const TextStyle authHeading = TextStyle(
    fontSize: largeHeading,
    fontWeight: bold,
    height: tightLineHeight,
  );

  // Logo text
  static const TextStyle logoText = TextStyle(
    fontSize: mediumHeading,
    fontWeight: bold,
  );

  // Profile name
  static const TextStyle profileName = TextStyle(
    fontSize: sectionHeading,
    fontWeight: bold,
  );

  // Modal header
  static const TextStyle modalHeader = TextStyle(
    fontSize: subheading,
    fontWeight: bold,
  );

  // Card heading
  static const TextStyle cardTitle = TextStyle(
    fontSize: cardHeading,
    fontWeight: bold,
  );

  // Post username
  static const TextStyle postUsername = TextStyle(
    fontSize: base,
    fontWeight: semiBold,
  );

  // Post content
  static const TextStyle postContent = TextStyle(
    fontSize: base,
    height: relaxedLineHeight,
  );

  // Post meta (timestamp, etc.)
  static const TextStyle postMeta = TextStyle(
    fontSize: extraSmall,
  );

  // Button text
  static const TextStyle buttonText = TextStyle(
    fontSize: base,
    fontWeight: semiBold,
  );

  // Action button text
  static const TextStyle actionButtonText = TextStyle(
    fontSize: mediumText,
    fontWeight: semiBold,
  );

  // Form label
  static const TextStyle formLabel = TextStyle(
    fontSize: small,
    fontWeight: semiBold,
  );

  // Input text
  static const TextStyle inputText = TextStyle(
    fontSize: base,
  );

  // Error message
  static const TextStyle errorText = TextStyle(
    fontSize: extraSmall,
  );

  // Verified badge
  static const TextStyle verifiedBadge = TextStyle(
    fontSize: extraSmall,
    fontWeight: medium,
  );

  // Human badge
  static const TextStyle humanBadge = TextStyle(
    fontSize: badgeText,
    fontWeight: semiBold,
  );

  // Trending item
  static const TextStyle trendingItem = TextStyle(
    fontSize: smallHeading,
    fontWeight: bold,
  );

  // Trending description
  static const TextStyle trendingDescription = TextStyle(
    fontSize: tiny,
  );

  // Wallet balance amount
  static const TextStyle walletBalanceAmount = TextStyle(
    fontSize: sectionHeading,
    fontWeight: bold,
  );

  // Wallet value
  static const TextStyle walletValue = TextStyle(
    fontSize: small,
  );

  // Feature text
  static const TextStyle featureText = TextStyle(
    fontSize: extraSmall,
    fontWeight: medium,
  );

  // Link text
  static const TextStyle linkText = TextStyle(
    fontSize: base,
    fontWeight: medium,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // RESPONSIVE HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /// Create a responsive font size (dampened scaling for readability)
  static double responsiveFontSize(BuildContext context, double size) {
    return ResponsiveUtils.scaleText(context, size);
  }

  /// Create a responsive icon size
  static double responsiveIconSize(BuildContext context, double size) {
    return ResponsiveUtils.scale(context, size);
  }

  /// Create a responsive TextStyle from a base style
  static TextStyle responsiveStyle(BuildContext context, TextStyle style) {
    if (style.fontSize == null) return style;
    return style.copyWith(
      fontSize: responsiveFontSize(context, style.fontSize!),
    );
  }

  /// Get responsive authHeading style
  static TextStyle responsiveAuthHeading(BuildContext context) {
    return responsiveStyle(context, authHeading);
  }

  /// Get responsive logoText style
  static TextStyle responsiveLogoText(BuildContext context) {
    return responsiveStyle(context, logoText);
  }

  /// Get responsive profileName style
  static TextStyle responsiveProfileName(BuildContext context) {
    return responsiveStyle(context, profileName);
  }

  /// Get responsive modalHeader style
  static TextStyle responsiveModalHeader(BuildContext context) {
    return responsiveStyle(context, modalHeader);
  }

  /// Get responsive cardTitle style
  static TextStyle responsiveCardTitle(BuildContext context) {
    return responsiveStyle(context, cardTitle);
  }

  /// Get responsive postUsername style
  static TextStyle responsivePostUsername(BuildContext context) {
    return responsiveStyle(context, postUsername);
  }

  /// Get responsive postContent style
  static TextStyle responsivePostContent(BuildContext context) {
    return responsiveStyle(context, postContent);
  }

  /// Get responsive postMeta style
  static TextStyle responsivePostMeta(BuildContext context) {
    return responsiveStyle(context, postMeta);
  }

  /// Get responsive buttonText style
  static TextStyle responsiveButtonText(BuildContext context) {
    return responsiveStyle(context, buttonText);
  }
}
