import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/platform_config.dart';
import '../services/supabase_service.dart';

/// Fetches and exposes the platform_config row so any widget/screen can read
/// admin-controlled settings without hitting the DB directly.
class PlatformConfigProvider with ChangeNotifier {
  PlatformConfig _config = const PlatformConfig();
  bool _isLoading = false;
  bool _loaded = false;

  PlatformConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isLoaded => _loaded;

  /// Call once at startup (and optionally on foreground resume).
  Future<void> fetch() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseService().client
          .from(SupabaseConfig.platformConfigTable)
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (response != null) {
        _config = PlatformConfig.fromMap(response);
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
