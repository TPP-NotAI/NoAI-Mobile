import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:rooverse/utils/validators.dart';
import 'package:rooverse/services/auth_service.dart';
import 'package:rooverse/services/supabase_service.dart';
import 'package:rooverse/config/supabase_config.dart';
import 'package:rooverse/models/user.dart';
import 'package:rooverse/services/referral_service.dart';
import 'package:rooverse/core/errors/error_mapper.dart';
import 'package:rooverse/core/errors/app_exception.dart';

/// Authentication status states.
enum AuthStatus { initial, loading, authenticated, unauthenticated, banned }

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
  bool _isPasswordResetPending = false; // For recovery flow
  RecoveryStep _recoveryStep = RecoveryStep.email;

  // Realtime subscription for profile changes (verified_human, etc.)
  RealtimeChannel? _profileChannel;
  String? _subscribedUserId;

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
          _unsubscribeFromProfileChanges();
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

      // Check user account status - enforce bans/suspensions
      if (_currentUser != null && _currentUser!.isBanned) {
        debugPrint('AuthProvider: User is banned');
        _error = 'Your account has been banned. Please contact support.';
        _status = AuthStatus.banned;
        notifyListeners();
        return;
      }

      if (_currentUser != null && _currentUser!.isSuspended) {
        debugPrint('AuthProvider: User is suspended');
        _error = 'Your account has been suspended. Please contact support.';
        // Allow them to see the app but with restricted access
      }

      _status = AuthStatus.authenticated;
      _error = _currentUser?.isSuspended == true
          ? 'Your account has been suspended. Some features are restricted.'
          : null;

      // Note: Wallet initialization is handled by WalletProvider.initWallet()
      // which is called from main.dart after auth state changes.
      // Don't call getOrCreateWallet here to avoid race conditions
      // that could award the welcome bonus multiple times.

      // Subscribe to realtime profile changes so the app reacts instantly
      // when Veriff's webhook updates verified_human (or any other field).
      _subscribeToProfileChanges(userId);
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

  /// Subscribe to realtime profile changes for [userId].
  ///
  /// When Veriff's webhook updates `verified_human` (or any other profile
  /// field), this fires and immediately reloads the user — so the app
  /// reacts without the user having to do anything.
  void _subscribeToProfileChanges(String userId) {
    // Already subscribed for this user — nothing to do.
    if (_subscribedUserId == userId && _profileChannel != null) return;

    // Remove any previous subscription first.
    _unsubscribeFromProfileChanges();

    _subscribedUserId = userId;
    _profileChannel = _supabase.client
        .channel('profile_changes_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.profilesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint(
              'AuthProvider: Profile changed via realtime — reloading user',
            );
            // Reload the full user object so all derived state
            // (isVerified, isActivated, verifiedHuman, etc.) updates.
            reloadCurrentUser();
          },
        )
        .subscribe((status, [error]) {
          debugPrint(
            'AuthProvider: Profile realtime subscription status: $status'
            '${error != null ? ', error: $error' : ''}',
          );
        });
  }

  /// Cancel the realtime profile subscription (called on sign-out).
  void _unsubscribeFromProfileChanges() {
    if (_profileChannel != null) {
      _supabase.client.removeChannel(_profileChannel!);
      _profileChannel = null;
      _subscribedUserId = null;
    }
  }

  /// Sign in with email and password.
  Future<void> signIn(String email, String password) async {
    final normalizedEmail = Validators.normalizeEmail(email);
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.signIn(email: normalizedEmail, password: password);
      // Auth state listener will handle the rest
    } catch (e, stack) {
      final appException = ErrorMapper.map(e, stack);
      _error = appException.userMessage;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      throw appException; // Re-throw for UI to handle with SnackBarUtils
    }
  }

  /// Sign up a new user.
  Future<void> signUp(String email, String password, String username) async {
    final normalizedEmail = Validators.normalizeEmail(email);
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final response = await _authService.signUp(
        email: normalizedEmail,
        password: password,
        username: username,
      );

      // Check if email confirmation is required
      if (response.user != null && response.session == null) {
        // Email confirmation required
        _pendingEmail = normalizedEmail;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // If session exists, user is auto-confirmed
      // Auth state listener will handle loading the user
    } catch (e, stack) {
      final appException = ErrorMapper.map(e, stack);
      _error = appException.userMessage;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      throw appException; // Re-throw for UI to handle with SnackBarUtils
    }
  }

  /// Check if a username is available.
  Future<bool> isUsernameAvailable(String username) async {
    if (username.isEmpty || username.length < 3) return false;
    return await _authService.isUsernameAvailable(username);
  }

  /// Verify email with OTP code.
  Future<void> verifyEmail(String token) async {
    if (_pendingEmail == null) {
      throw ValidationException.required('email verification');
    }

    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyOtp(email: _pendingEmail!, token: token);
      _pendingEmail = null;
      // Auth state listener will handle the rest
    } catch (e, stack) {
      final appException = ErrorMapper.map(e, stack);
      _error = appException.userMessage;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      throw appException; // Re-throw for UI to handle with SnackBarUtils
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
    // Cancel profile realtime subscription before signing out.
    _unsubscribeFromProfileChanges();

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

  /// Request a login OTP for phone-based authentication.
  Future<bool> sendLoginOtp(String phoneNumber) async {
    _error = null;
    notifyListeners();

    try {
      await _authService.sendLoginOtp(phoneNumber);
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send login code';
      notifyListeners();
      return false;
    }
  }

  /// Verify the login OTP code and sign in.
  Future<bool> verifyLoginOtp(String phoneNumber, String token) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.verifyLoginOtp(phone: phoneNumber, token: token);
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e.message);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to verify login code';
      _status = AuthStatus.unauthenticated;
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

      // Complete referral if exists
      try {
        final referralService = ReferralService();
        await referralService.completeReferral(userId);
      } catch (e) {
        debugPrint('AuthProvider: Error completing referral - $e');
      }

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
      return 'Please enter a valid email address';
    }
    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('too many requests')) {
      return 'Too many attempts. Please try again later';
    }

    // Return the original message for other email-related errors
    return message;
  }
}
