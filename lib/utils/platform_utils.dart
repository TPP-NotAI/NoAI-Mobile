import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Utility class for platform detection and platform-specific behavior
class PlatformUtils {
  /// Check if the current platform is iOS (native or web on iOS)
  static bool get isIOS {
    if (kIsWeb) {
      // On web, check user agent for iOS devices
      return defaultTargetPlatform == TargetPlatform.iOS;
    }
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Check if the current platform is Android (native or web on Android)
  static bool get isAndroid {
    if (kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.android;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on mobile (iOS or Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Check if running on desktop
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Get the current platform for UI decisions
  static TargetPlatform get currentPlatform => defaultTargetPlatform;

  /// Determine if we should use Cupertino (iOS-style) widgets
  static bool shouldUseCupertino(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.iOS || isIOS;
  }

  /// Determine if we should use Material (Android-style) widgets
  static bool shouldUseMaterial(BuildContext context) {
    return !shouldUseCupertino(context);
  }
}
