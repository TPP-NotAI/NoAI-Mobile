import 'dart:ui' as ui;

enum DeepLinkDestination {
  helpCenter,
  contactSupport,
  verificationCallback,
}

/// Resolves platform deep links into app destinations.
class DeepLinkService {
  final DeepLinkDestination? _initialDestination;
  bool _handled = false;

  DeepLinkService() : _initialDestination = _parseInitialDestination();

  /// Returns the destination that should be handled once and prevents it from
  /// being handled again.
  DeepLinkDestination? consumePendingDestination() {
    if (_handled) return null;
    final destination = _initialDestination;
    if (destination == null) return null;
    _handled = true;
    return destination;
  }

  static DeepLinkDestination? _parseInitialDestination() {
    final fromUriBase = _toDestination(Uri.base);
    if (fromUriBase != null) {
      return fromUriBase;
    }

    final routeName = ui.PlatformDispatcher.instance.defaultRouteName;
    return _toDestinationFromString(routeName);
  }

  static DeepLinkDestination? _toDestinationFromString(String? routeName) {
    if (routeName == null || routeName.isEmpty) return null;
    final uri = Uri.tryParse(routeName);
    if (uri == null) return null;
    return _toDestination(uri);
  }

  static DeepLinkDestination? _toDestination(Uri uri) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) return null;
    final first = segments.first.toLowerCase();

    if (first == 'help-center' || first == 'help_center') {
      return DeepLinkDestination.helpCenter;
    }
    if (first == 'contact-support' || first == 'contact_support') {
      return DeepLinkDestination.contactSupport;
    }
    if (first == 'verification') {
      return DeepLinkDestination.verificationCallback;
    }
    return null;
  }
}
