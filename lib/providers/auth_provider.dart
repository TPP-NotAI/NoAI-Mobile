import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../models/user.dart';

/// Authentication status states.
enum AuthStatus { initial, loading, authenticated, unauthenticated }

enum RecoveryStep { email, otp, newPassword, success }

/// Provider for managing authentication state.
///
/// Listens to Supabase auth state changes and manages the current user profile.
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseService _supabase = SupabaseService();

  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _error;
  String? _pendingEmail; // For verification flow
  String? _pendingUsername; // Username from signup, used to fix display_name
  bool _isPasswordResetPending = false; // For recovery flow
  RecoveryStep _recoveryStep = RecoveryStep.email;

  /// Current authentication status.
  AuthStatus get status => _status;

  /// The currently authenticated user's profile.
  User? get currentUser => _currentUser;

  /// Last error message, if any.
  String? get error => _error;

  /// Whether the user is authenticated.
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Email pending verification (set during signup).
  /// Email pending verification (set during signup).
  String? get pendingEmail => _pendingEmail;

  /// Whether a password reset is in progress.
  bool get isPasswordResetPending => _isPasswordResetPending;

  /// Current step in the recovery flow.
  RecoveryStep get recoveryStep => _recoveryStep;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize auth state and listen for changes.
  void _initializeAuth() {
    // Check for existing session
    final session = _supabase.currentSession;
    if (session != null) {
      _loadCurrentUser(session.user.id);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }

    // Listen to auth state changes
    _supabase.authStateChanges.listen((event) {
      debugPrint('AuthProvider: Auth event - ${event.event}');

      switch (event.event) {
        case AuthChangeEvent.signedIn:
          if (event.session?.user != null) {
            _loadCurrentUser(event.session!.user.id);
          }
          break;
        case AuthChangeEvent.signedOut:
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
          _error = null;
          _isPasswordResetPending = false;
          _recoveryStep = RecoveryStep.email;
          notifyListeners();
          break;
        case AuthChangeEvent.tokenRefreshed:
          // Token refreshed, user still authenticated
          break;
        case AuthChangeEvent.userUpdated:
          // Reload user profile
          if (event.session?.user != null) {
            _loadCurrentUser(event.session!.user.id);
          }
          break;
        default:
          break;
      }
    });
  }

  /// Load the current user's profile from Supabase.
  Future<void> _loadCurrentUser(String userId, {int retryCount = 0}) async {
    try {
      if (!_isPasswordResetPending) {
        _status = AuthStatus.loading;
        notifyListeners();
      }

      debugPrint(
        'AuthProvider: Loading profile for user: $userId (attempt ${retryCount + 1})',
      );

      // Fetch profile with wallet data
      final response = await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .select('*, ${SupabaseConfig.walletsTable}(*)')
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('AuthProvider: Profile response: $response');

      if (response == null) {
        // Profile doesn't exist yet - this can happen if the database trigger
        // hasn't completed yet. Retry a few times with a delay.
        debugPrint('AuthProvider: No profile found for user $userId');

        if (retryCount < 3) {
          debugPrint('AuthProvider: Retrying in 1 second...');
          await Future.delayed(const Duration(seconds: 1));
          return _loadCurrentUser(userId, retryCount: retryCount + 1);
        }

        // After retries, user is authenticated but has no profile
        // They may need to complete profile setup
        _currentUser = null;
        _status = AuthStatus.authenticated;
        _error = null;
        notifyListeners();
        return;
      }

      final wallet = response[SupabaseConfig.walletsTable];
      debugPrint('AuthProvider: Wallet data: $wallet');
      debugPrint(
        'AuthProvider: display_name from DB: ${response['display_name']}',
      );
      debugPrint('AuthProvider: username from DB: ${response['username']}');

      final authUser = _supabase.client.auth.currentUser;
      _currentUser = User.fromSupabase(
        response,
        wallet: wallet,
      ).copyWith(email: authUser?.email);
      debugPrint(
        'AuthProvider: User displayName after parse: ${_currentUser?.displayName}',
      );

      // If display_name is empty and we have a pending username from signup, fix it
      if (_currentUser != null &&
          _currentUser!.displayName.isEmpty &&
          _pendingUsername != null) {
        debugPrint(
          'AuthProvider: Fixing empty display_name with username: $_pendingUsername',
        );
        await _fixEmptyDisplayName(userId, _pendingUsername!);
        _pendingUsername = null;
      }

      _status = AuthStatus.authenticated;
      _error = null;
    } catch (e) {
      debugPrint('AuthProvider: Error loading user - $e');
      // Even if profile loading fails, user is still authenticated
      // Set authenticated status so they can access the app
      _currentUser = null;
      _status = AuthStatus.authenticated;
      _error = null;
    }
    notifyListeners();
  }

  /// Reload the current user's profile from Supabase.
  ///
  /// Call this after profile updates or when the profile may have been
  /// created by a database trigger.
  Future<void> reloadCurrentUser() async {
    final session = _supabase.currentSession;
    if (session != null) {
      await _loadCurrentUser(session.user.id);
    }
  }

  /// Fix empty display_name by updating it with the username.
  Future<void> _fixEmptyDisplayName(String userId, String displayName) async {
    try {
      await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .update({'display_name': displayName})
          .eq('user_id', userId);

      // Update local user object
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(displayName: displayName);
        notifyListeners();
      }
      debugPrint('AuthProvider: Fixed display_name to: $displayName');
    } catch (e) {
      debugPrint('AuthProvider: Failed to fix display_name - $e');
    }
  }

  /// Sign in with email and password.
  Future<bool> signIn(String email, String password) async {
    _error = null;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      // Auth state listener will handle the rest
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Sign up a new user.
  Future<bool> signUp(String email, String password, String username) async {
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        username: username,
      );

      // Check if email confirmation is required
      if (response.user != null && response.session == null) {
        // Email confirmation required
        _pendingEmail = email;
        _pendingUsername = username;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      }

      // If session exists, user is auto-confirmed
      // Auth state listener will handle loading the user
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } on PostgrestException catch (e) {
      // Handle database errors (e.g., duplicate username)
      if (e.message.contains('duplicate') ||
          e.message.contains('unique constraint')) {
        _error = 'Username is already taken';
      } else {
        _error = 'Failed to create profile';
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Verify email with OTP code.
  Future<bool> verifyEmail(String token) async {
    if (_pendingEmail == null) {
      _error = 'No email pending verification';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyOtp(email: _pendingEmail!, token: token);
      _pendingEmail = null;
      // Auth state listener will handle the rest
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Verification failed';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Resend email confirmation.
  Future<bool> resendConfirmation() async {
    if (_pendingEmail == null) {
      _error = 'No email pending verification';
      notifyListeners();
      return false;
    }

    try {
      await _authService.resendEmailConfirmation(_pendingEmail!);
      return true;
    } catch (e) {
      _error = 'Failed to resend confirmation email';
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email.
  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      _pendingEmail = email; // Store for verification step
      _isPasswordResetPending = true;
      _recoveryStep = RecoveryStep.otp;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send reset email';
      notifyListeners();
      return false;
    }
  }

  /// Verify recovery OTP code.
  Future<bool> verifyRecoveryOtp(String token) async {
    if (_pendingEmail == null) {
      _error = 'No email pending recovery';
      notifyListeners();
      return false;
    }

    _error = null;
    notifyListeners();

    try {
      // For recovery, Supabase verifyOTP with type 'recovery'
      await _authService
          .verifyRecoveryOtp(email: _pendingEmail!, token: token)
          .timeout(const Duration(seconds: 30));

      // OTP verified, user can now reset password
      _recoveryStep = RecoveryStep.newPassword;
      _isPasswordResetPending = true; // Ensure this stays true
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } on TimeoutException catch (e) {
      _error = 'Verification timed out. Please try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Verification failed';
      notifyListeners();
      return false;
    }
  }

  /// Update password for the currently logged in user.
  Future<bool> updatePassword(String newPassword) async {
    try {
      _error = null;
      notifyListeners();
      await _authService.updatePassword(newPassword);
      _recoveryStep = RecoveryStep.success;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update password';
      notifyListeners();
      return false;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      // Manually update status to ensure UI responds immediately
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      _isPasswordResetPending = false;
      _recoveryStep = RecoveryStep.email;
      notifyListeners();
      // Auth state listener will also handle this, but manual update ensures immediate response
    } catch (e) {
      debugPrint('AuthProvider: Error signing out - $e');
      // Even on error, set status to unauthenticated to allow user to proceed
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _error = null;
      _isPasswordResetPending = false;
      _recoveryStep = RecoveryStep.email;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PHONE VERIFICATION
  // ─────────────────────────────────────────────────────────────

  /// Send OTP to phone number for verification.
  Future<bool> sendPhoneOtp(String phoneNumber) async {
    try {
      _error = null;

      await _authService.sendPhoneOtp(phoneNumber);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send verification code';
      notifyListeners();
      return false;
    }
  }

  /// Verify phone OTP code.
  Future<bool> verifyPhoneOtp(String phoneNumber, String token) async {
    try {
      _error = null;

      await _authService.verifyPhoneOtp(phone: phoneNumber, token: token);

      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Phone verification failed';
      notifyListeners();
      return false;
    }
  }

  /// Update user's verification status in the database.
  Future<bool> updateVerificationStatus(String method) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.client
          .from(SupabaseConfig.profilesTable)
          .update({
            'verified_human': 'verified',
            'verification_method': method,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      // Reload user to get updated status
      await reloadCurrentUser();
      return true;
    } catch (e) {
      debugPrint('AuthProvider: Error updating verification status - $e');
      return false;
    }
  }

  /// Clear any pending error or reset state.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset the recovery flow state.
  void resetRecoveryFlow() {
    _isPasswordResetPending = false;
    _recoveryStep = RecoveryStep.email;
    _pendingEmail = null;
    notifyListeners();
  }

  /// Map Supabase auth errors to user-friendly messages.
  String _mapAuthError(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('invalid login credentials') ||
        lowerMessage.contains('invalid email or password')) {
      return 'Invalid email or password';
    }
    if (lowerMessage.contains('email not confirmed')) {
      return 'Please verify your email before signing in';
    }
    if (lowerMessage.contains('user already registered')) {
      return 'An account with this email already exists';
    }
    if (lowerMessage.contains('password')) {
      return 'Password must be at least 6 characters';
    }
    if (lowerMessage.contains('invalid email') ||
        lowerMessage.contains('email address is not valid')) {
      return message; // Return the original Supabase error message for debugging
    }
    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('too many requests')) {
      return 'Too many attempts. Please try again later';
    }

    // Return the original message for other email-related errors
    return message;
  }
}
