import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';

/// Service to track and reward referrals
class ReferralService {
  final _client = SupabaseService().client;
  final _walletRepo = WalletRepository();

  /// Generate a unique referral code for a user
  Future<String> generateReferralCode(String userId) async {
    try {
      // Check if user already has a referral code
      final existing = await _client
          .from('referral_codes')
          .select('code')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return existing['code'] as String;
      }

      // Generate a new code (8 characters: first 4 of user ID + 4 random)
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final code =
          '${userId.substring(0, 4).toUpperCase()}${timestamp.substring(timestamp.length - 4)}';

      // Store the referral code
      await _client.from('referral_codes').insert({
        'user_id': userId,
        'code': code,
        'created_at': DateTime.now().toIso8601String(),
      });

      return code;
    } catch (e) {
      debugPrint('ReferralService: Error generating referral code - $e');
      rethrow;
    }
  }

  /// Apply a referral code when a new user signs up
  /// Awards 50 ROOK to the referrer
  Future<bool> applyReferralCode(String newUserId, String referralCode) async {
    try {
      // Find the referrer
      final referralData = await _client
          .from('referral_codes')
          .select('user_id')
          .eq('code', referralCode.toUpperCase())
          .maybeSingle();

      if (referralData == null) {
        debugPrint('ReferralService: Invalid referral code: $referralCode');
        return false;
      }

      final referrerId = referralData['user_id'] as String;

      // Prevent self-referral
      if (referrerId == newUserId) {
        debugPrint('ReferralService: Cannot refer yourself');
        return false;
      }

      // Check if this user was already referred
      final existingReferral = await _client
          .from('referrals')
          .select('id')
          .eq('referred_user_id', newUserId)
          .maybeSingle();

      if (existingReferral != null) {
        debugPrint('ReferralService: User $newUserId was already referred');
        return false;
      }

      // Record the referral
      await _client.from('referrals').insert({
        'referrer_user_id': referrerId,
        'referred_user_id': newUserId,
        'referral_code': referralCode.toUpperCase(),
        'status': 'pending', // Will be 'completed' after new user is verified
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
        'ReferralService: Recorded referral from $referrerId to $newUserId',
      );
      return true;
    } catch (e) {
      debugPrint('ReferralService: Error applying referral code - $e');
      return false;
    }
  }

  /// Complete a referral and award ROOK when the referred user gets verified
  /// This should be called when a new user completes verification
  Future<bool> completeReferral(String referredUserId) async {
    try {
      // Find the pending referral
      final referral = await _client
          .from('referrals')
          .select('id, referrer_user_id, referral_code')
          .eq('referred_user_id', referredUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (referral == null) {
        debugPrint(
          'ReferralService: No pending referral found for user $referredUserId',
        );
        return false;
      }

      final referrerId = referral['referrer_user_id'] as String;
      final referralId = referral['id'] as String;

      // Award 50 ROOK to the referrer
      await _walletRepo.earnRoo(
        userId: referrerId,
        activityType: RookenActivityType.referral,
        metadata: {
          'referred_user_id': referredUserId,
          'referral_code': referral['referral_code'],
          'completion_date': DateTime.now().toIso8601String(),
        },
      );

      // Update referral status
      await _client
          .from('referrals')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', referralId);

      debugPrint(
        'ReferralService: Completed referral and awarded 50 ROOK to $referrerId',
      );
      return true;
    } catch (e) {
      debugPrint('ReferralService: Error completing referral - $e');
      return false;
    }
  }

  /// Get referral stats for a user
  Future<Map<String, dynamic>> getReferralStats(String userId) async {
    try {
      final referrals = await _client
          .from('referrals')
          .select('status')
          .eq('referrer_user_id', userId);

      final total = (referrals as List).length;
      final completed = referrals
          .where((r) => r['status'] == 'completed')
          .length;
      final pending = referrals.where((r) => r['status'] == 'pending').length;

      return {
        'total_referrals': total,
        'completed_referrals': completed,
        'pending_referrals': pending,
        'total_earned': completed * 50, // 50 ROOK per completed referral
      };
    } catch (e) {
      debugPrint('ReferralService: Error getting referral stats - $e');
      return {
        'total_referrals': 0,
        'completed_referrals': 0,
        'pending_referrals': 0,
        'total_earned': 0,
      };
    }
  }

  /// Get user's referral code
  Future<String?> getUserReferralCode(String userId) async {
    try {
      final result = await _client
          .from('referral_codes')
          .select('code')
          .eq('user_id', userId)
          .maybeSingle();

      return result?['code'] as String?;
    } catch (e) {
      debugPrint('ReferralService: Error getting user referral code - $e');
      return null;
    }
  }
}
