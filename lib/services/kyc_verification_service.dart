import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Exception thrown when a user tries to perform an action that requires KYC verification
class KycNotVerifiedException implements Exception {
  final String message;

  const KycNotVerifiedException([this.message = 'KYC verification required to perform this action']);

  @override
  String toString() => message;
}

/// Exception thrown when a user is verified but has not yet purchased ROO.
/// Users must buy at least 1 ROO via Stripe to activate full platform access.
class NotActivatedException implements Exception {
  final String message;

  const NotActivatedException([
    this.message =
        'Please buy at least 1 ROO to activate your account and unlock posting, commenting, and all platform features.',
  ]);

  @override
  String toString() => message;
}

/// Service to check and enforce KYC verification requirements
class KycVerificationService {
  static final KycVerificationService _instance = KycVerificationService._internal();
  factory KycVerificationService() => _instance;
  KycVerificationService._internal();

  final _supabase = SupabaseService().client;

  // Cache the verification status to avoid repeated DB calls
  String? _cachedUserId;
  bool? _cachedIsVerified;
  String? _cachedVerifiedHuman;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Returns the raw verified_human string: 'unverified', 'pending', or 'verified'.
  /// Uses the same cache as [isCurrentUserVerified].
  Future<String> _getCurrentVerifiedHumanStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 'unverified';

    // Check cache validity
    if (_cachedUserId == userId &&
        _cachedVerifiedHuman != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedVerifiedHuman!;
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select('verified_human')
          .eq('user_id', userId)
          .single();

      final verifiedHuman = response['verified_human'] as String? ?? 'unverified';

      // Update cache
      _cachedUserId = userId;
      _cachedVerifiedHuman = verifiedHuman;
      _cachedIsVerified = verifiedHuman == 'verified';
      _cacheTime = DateTime.now();

      return verifiedHuman;
    } catch (e) {
      debugPrint('KycVerificationService: Error checking verification status - $e');
      return 'unverified';
    }
  }

  /// Check if the current user has completed KYC verification
  /// Returns true if verified, false otherwise
  Future<bool> isCurrentUserVerified() async {
    final status = await _getCurrentVerifiedHumanStatus();
    return status == 'verified';
  }

  /// Require KYC verification for an action.
  /// Throws [KycNotVerifiedException] if not verified (handles pending state separately).
  Future<void> requireVerification() async {
    final status = await _getCurrentVerifiedHumanStatus();
    if (status == 'verified') return;
    if (status == 'pending') {
      throw const KycNotVerifiedException(
        'Your verification is being reviewed. You will be notified once approved.',
      );
    }
    throw const KycNotVerifiedException(
      'Please complete human verification (KYC) before posting, commenting, or liking content.',
    );
  }

  /// Require full activation for an action: verified AND has purchased ROO (balance > 0).
  ///
  /// [currentBalance] — pass the user's current wallet balance (from WalletProvider).
  ///
  /// Throws [KycNotVerifiedException] if not verified or pending.
  /// Throws [NotActivatedException] if verified but balance is 0.
  Future<void> requireActivation({double currentBalance = 0.0}) async {
    final status = await _getCurrentVerifiedHumanStatus();

    if (status == 'pending') {
      throw const KycNotVerifiedException(
        'Your verification is being reviewed. You will be notified once approved.',
      );
    }

    if (status != 'verified') {
      throw const KycNotVerifiedException(
        'Please complete human verification (KYC) before posting, commenting, or liking content.',
      );
    }

    // Verified — now check balance
    if (currentBalance <= 0) {
      throw const NotActivatedException();
    }
  }

  /// Clear the cached verification status (call on logout or when status changes)
  void clearCache() {
    _cachedUserId = null;
    _cachedIsVerified = null;
    _cachedVerifiedHuman = null;
    _cacheTime = null;
  }

  /// Update cache directly (call after successful verification)
  void setVerified(String userId, bool isVerified) {
    _cachedUserId = userId;
    _cachedIsVerified = isVerified;
    _cachedVerifiedHuman = isVerified ? 'verified' : 'unverified';
    _cacheTime = DateTime.now();
  }
}
