/// Spacing system matching web application specs
/// Base unit: 1rem = 16px
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
}
