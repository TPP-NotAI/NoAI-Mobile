import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Exception thrown when a user tries to perform an action that requires KYC verification
class KycNotVerifiedException implements Exception {
  final String message;

  const KycNotVerifiedException([this.message = 'KYC verification required to perform this action']);

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
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Check if the current user has completed KYC verification
  /// Returns true if verified, false otherwise
  Future<bool> isCurrentUserVerified() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    // Check cache validity
    if (_cachedUserId == userId &&
        _cachedIsVerified != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedIsVerified!;
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select('verified_human')
          .eq('user_id', userId)
          .single();

      final verifiedHuman = response['verified_human'] as String? ?? 'unverified';
      final isVerified = verifiedHuman == 'verified';

      // Update cache
      _cachedUserId = userId;
      _cachedIsVerified = isVerified;
      _cacheTime = DateTime.now();

      return isVerified;
    } catch (e) {
      debugPrint('KycVerificationService: Error checking verification status - $e');
      return false;
    }
  }

  /// Require KYC verification for an action
  /// Throws KycNotVerifiedException if not verified
  Future<void> requireVerification() async {
    final isVerified = await isCurrentUserVerified();
    if (!isVerified) {
      throw const KycNotVerifiedException(
        'Please complete human verification (KYC) before posting, commenting, or liking content.',
      );
    }
  }

  /// Clear the cached verification status (call on logout or when status changes)
  void clearCache() {
    _cachedUserId = null;
    _cachedIsVerified = null;
    _cacheTime = null;
  }

  /// Update cache directly (call after successful verification)
  void setVerified(String userId, bool isVerified) {
    _cachedUserId = userId;
    _cachedIsVerified = isVerified;
    _cacheTime = DateTime.now();
  }
}
