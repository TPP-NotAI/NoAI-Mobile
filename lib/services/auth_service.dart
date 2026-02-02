import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for handling authentication operations with Supabase.
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = SupabaseService();

  /// Sign up a new user with email and password.
  ///
  /// Creates the auth user. Profile creation is handled by database triggers.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': displayName ?? username},
    );

    return response;
  }

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Refresh the current session.
  Future<Session?> refreshSession() async {
    final response = await _supabase.auth.refreshSession();
    return response.session;
  }

  /// Resend the email confirmation OTP.
  Future<void> resendEmailConfirmation(String email) async {
    await _supabase.auth.resend(type: OtpType.signup, email: email);
  }

  /// Verify OTP for email confirmation.
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  /// Sign in with OAuth provider (Google, Apple, etc.).
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await _supabase.auth.signInWithOAuth(provider);
  }

  /// Update the current user's password.
  ///
  /// Requires the user to be authenticated.
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Update the current user's email.
  ///
  /// Requires the user to be authenticated. A confirmation email will be sent.
  Future<void> updateEmail(String newEmail) async {
    await _supabase.auth.updateUser(UserAttributes(email: newEmail));
  }

  // ─────────────────────────────────────────────────────────────
  // PHONE VERIFICATION
  // ─────────────────────────────────────────────────────────────

  /// Send OTP to phone number for verification (for authenticated users).
  Future<void> sendPhoneOtp(String phoneNumber) async {
    await _supabase.auth.updateUser(UserAttributes(phone: phoneNumber));
  }

  /// Verify phone OTP code.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.phoneChange,
    );
  }

  /// Send OTP to phone number for login (human verification + sign-in).
  Future<void> sendLoginOtp(String phoneNumber) async {
    await _supabase.auth.signInWithOtp(phone: phoneNumber);
  }

  /// Verify phone OTP code for login.
  Future<AuthResponse> verifyLoginOtp({
    required String phone,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Verify OTP for recovery (password reset).
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }
}
