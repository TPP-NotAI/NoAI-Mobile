import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gotrue/gotrue.dart' as gotrue_types;
import '../config/supabase_config.dart';

/// Singleton service for Supabase client access.
///
/// Initialize this service in main() before runApp():
/// ```dart
/// await SupabaseService().initialize();
/// ```
class SupabaseService {
  // Singleton pattern matching existing ApiService
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;
  bool _initialized = false;

  /// The Supabase client instance.
  SupabaseClient get client {
    _assertInitialized();
    return _client;
  }

  /// The Supabase Auth client.
  GoTrueClient get auth {
    _assertInitialized();
    return _client.auth;
  }

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// The currently authenticated user, or null if not authenticated.
  gotrue_types.User? get currentUser =>
      _initialized ? _client.auth.currentUser : null;

  /// The current session, or null if not authenticated.
  Session? get currentSession =>
      _initialized ? _client.auth.currentSession : null;

  /// Whether there is an authenticated user.
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes for reactive updates.
  Stream<AuthState> get authStateChanges {
    _assertInitialized();
    return _client.auth.onAuthStateChange;
  }

  /// Initialize the Supabase client.
  ///
  /// This must be called once before using any Supabase features.
  /// Typically called in main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('SupabaseService: Already initialized');
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: kDebugMode,
    );

    _client = Supabase.instance.client;
    _initialized = true;

    debugPrint('SupabaseService: Initialized successfully');
  }

  /// Assert that the service has been initialized.
  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'SupabaseService has not been initialized. '
        'Call SupabaseService().initialize() in main() before using.',
      );
    }
  }
}
