import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive_utils.dart';

/// Typography system — Rooverse Brand (official style guide)
///
/// Primary font:   Be Vietnam Pro  — UI, body, buttons, labels
/// Secondary font: Playfair Display — headings, display, editorial
///
class AppTypography {
  // ─────────────────────────────────────────────────────────────────────────
  // FONT FAMILIES
  // ─────────────────────────────────────────────────────────────────────────

  static String get primaryFamily => GoogleFonts.beVietnamPro().fontFamily!;
  static String get secondaryFamily => GoogleFonts.playfairDisplay().fontFamily!;

  /// Full Montserrat-based TextTheme for ThemeData — uses Be Vietnam Pro
  static TextTheme get textTheme => GoogleFonts.beVietnamProTextTheme();

  // ─────────────────────────────────────────────────────────────────────────
  // FONT SIZES (1rem = 16px)
  // ─────────────────────────────────────────────────────────────────────────

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
  static const double tinyIcon = 11.2;
  static const double smallIcon = 17.6;
  static const double mediumIcon = 19.2;
  static const double largeIcon = 20.8;
  static const double extraLargeIcon = 24.0;
  static const double logoShield = 28.8;
  static const double authShield = 40.0;
  static const double modalClose = 32.0;
  static const double walletBalance = 32.0;

  // ─────────────────────────────────────────────────────────────────────────
  // FONT WEIGHTS
  // ─────────────────────────────────────────────────────────────────────────

  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // Line Heights
  static const double defaultLineHeight = 1.5;
  static const double tightLineHeight = 1.1;
  static const double relaxedLineHeight = 1.7;

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT STYLES
  // Uses Playfair Display for display/heading, Be Vietnam Pro for everything else
  // ─────────────────────────────────────────────────────────────────────────

  /// Auth page main heading — Playfair Display (editorial)
  static TextStyle get authHeading => GoogleFonts.playfairDisplay(
        fontSize: largeHeading,
        fontWeight: bold,
        height: tightLineHeight,
      );

  /// Logo wordmark — Be Vietnam Pro extra bold
  static TextStyle get logoText => GoogleFonts.beVietnamPro(
        fontSize: mediumHeading,
        fontWeight: extraBold,
        letterSpacing: 1.5,
      );

  /// Profile display name — Playfair Display
  static TextStyle get profileName => GoogleFonts.playfairDisplay(
        fontSize: sectionHeading,
        fontWeight: bold,
      );

  /// Modal / sheet header — Be Vietnam Pro
  static TextStyle get modalHeader => GoogleFonts.beVietnamPro(
        fontSize: subheading,
        fontWeight: bold,
      );

  /// Card heading — Be Vietnam Pro
  static TextStyle get cardTitle => GoogleFonts.beVietnamPro(
        fontSize: cardHeading,
        fontWeight: bold,
      );

  /// Post username — Be Vietnam Pro
  static TextStyle get postUsername => GoogleFonts.beVietnamPro(
        fontSize: base,
        fontWeight: semiBold,
      );

  /// Post body text — Be Vietnam Pro
  static TextStyle get postContent => GoogleFonts.beVietnamPro(
        fontSize: base,
        fontWeight: normal,
        height: relaxedLineHeight,
      );

  /// Timestamp / meta — Be Vietnam Pro
  static TextStyle get postMeta => GoogleFonts.beVietnamPro(
        fontSize: extraSmall,
        fontWeight: normal,
      );

  /// Button label — Be Vietnam Pro
  static TextStyle get buttonText => GoogleFonts.beVietnamPro(
        fontSize: base,
        fontWeight: semiBold,
        letterSpacing: 0.3,
      );

  /// Smaller action button — Be Vietnam Pro
  static TextStyle get actionButtonText => GoogleFonts.beVietnamPro(
        fontSize: mediumText,
        fontWeight: semiBold,
      );

  /// Form label — Be Vietnam Pro
  static TextStyle get formLabel => GoogleFonts.beVietnamPro(
        fontSize: small,
        fontWeight: semiBold,
      );

  /// Input field text — Be Vietnam Pro
  static TextStyle get inputText => GoogleFonts.beVietnamPro(
        fontSize: base,
        fontWeight: normal,
      );

  /// Error message — Be Vietnam Pro
  static TextStyle get errorText => GoogleFonts.beVietnamPro(
        fontSize: extraSmall,
        fontWeight: normal,
      );

  /// Verified badge label — Be Vietnam Pro
  static TextStyle get verifiedBadge => GoogleFonts.beVietnamPro(
        fontSize: extraSmall,
        fontWeight: medium,
      );

  /// Human badge — Be Vietnam Pro
  static TextStyle get humanBadge => GoogleFonts.beVietnamPro(
        fontSize: badgeText,
        fontWeight: semiBold,
      );

  /// Trending item title — Playfair Display
  static TextStyle get trendingItem => GoogleFonts.playfairDisplay(
        fontSize: smallHeading,
        fontWeight: bold,
      );

  /// Trending description — Be Vietnam Pro
  static TextStyle get trendingDescription => GoogleFonts.beVietnamPro(
        fontSize: tiny,
        fontWeight: normal,
      );

  /// Wallet balance — Playfair Display (display number)
  static TextStyle get walletBalanceAmount => GoogleFonts.playfairDisplay(
        fontSize: sectionHeading,
        fontWeight: bold,
      );

  /// Wallet secondary value — Be Vietnam Pro
  static TextStyle get walletValue => GoogleFonts.beVietnamPro(
        fontSize: small,
        fontWeight: normal,
      );

  /// Feature label — Be Vietnam Pro
  static TextStyle get featureText => GoogleFonts.beVietnamPro(
        fontSize: extraSmall,
        fontWeight: medium,
      );

  /// Link text — Be Vietnam Pro
  static TextStyle get linkText => GoogleFonts.beVietnamPro(
        fontSize: base,
        fontWeight: medium,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // RESPONSIVE HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  static double responsiveFontSize(BuildContext context, double size) {
    return ResponsiveUtils.scaleText(context, size);
  }

  static double responsiveIconSize(BuildContext context, double size) {
    return ResponsiveUtils.scale(context, size);
  }

  static TextStyle responsiveStyle(BuildContext context, TextStyle style) {
    if (style.fontSize == null) return style;
    return style.copyWith(
      fontSize: responsiveFontSize(context, style.fontSize!),
    );
  }

  static TextStyle responsiveAuthHeading(BuildContext context) =>
      responsiveStyle(context, authHeading);

  static TextStyle responsiveLogoText(BuildContext context) =>
      responsiveStyle(context, logoText);

  static TextStyle responsiveProfileName(BuildContext context) =>
      responsiveStyle(context, profileName);

  static TextStyle responsiveModalHeader(BuildContext context) =>
      responsiveStyle(context, modalHeader);

  static TextStyle responsiveCardTitle(BuildContext context) =>
      responsiveStyle(context, cardTitle);

  static TextStyle responsivePostUsername(BuildContext context) =>
      responsiveStyle(context, postUsername);

  static TextStyle responsivePostContent(BuildContext context) =>
      responsiveStyle(context, postContent);

  static TextStyle responsivePostMeta(BuildContext context) =>
      responsiveStyle(context, postMeta);

  static TextStyle responsiveButtonText(BuildContext context) =>
      responsiveStyle(context, buttonText);
}
