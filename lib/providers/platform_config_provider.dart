import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/platform_config.dart';
import '../services/supabase_service.dart';

/// Fetches and exposes the platform_config row so any widget/screen can read
/// admin-controlled settings without hitting the DB directly.
class PlatformConfigProvider with ChangeNotifier {
  static PlatformConfig _currentConfig = const PlatformConfig();

  /// Read-only access to the latest config from non-widget code (e.g. services).
  static PlatformConfig get current => _currentConfig;

  PlatformConfig _config = const PlatformConfig();
  bool _isLoading = false;
  bool _loaded = false;

  PlatformConfigProvider() {
    debugPrint('PlatformConfigProvider: created, scheduling fetch...');
    Future.microtask(fetch);
  }

  PlatformConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoaded => _loaded;

  /// Call once at startup (and optionally on foreground resume).
  Future<void> fetch() async {
    debugPrint('PlatformConfigProvider: fetch() called, _isLoading=$_isLoading');
    if (_isLoading) return;
    _isLoading = true;

    try {
      debugPrint('PlatformConfigProvider: querying Supabase...');
      final response = await SupabaseService().client
          .from(SupabaseConfig.platformConfigTable)
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (response != null) {
        _config = PlatformConfig.fromMap(response);
        _currentConfig = _config;
        debugPrint('PlatformConfigProvider: Loaded platform_name="${_config.platformName}"');
      } else {
        debugPrint('PlatformConfigProvider: No row returned from platform_config (id=1) — using defaults');
      }
      _loaded = true;
    } catch (e) {
      debugPrint('PlatformConfigProvider: Failed to fetch config - $e');
      // Keep existing (default) config so the app still works
      _loaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
