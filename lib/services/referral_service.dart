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

      // Generate a new code (8 characters: first 4 of user ID + 4 timestamp digits)
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final code =
          '${userId.substring(0, 4).toUpperCase()}${timestamp.substring(timestamp.length - 4)}';

      // Store the referral code
      await _client.from('referral_codes').insert({
        'user_id': userId,
        'code': code,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Also store in profiles.referral_code for quick lookup
      await _client
          .from('profiles')
          .update({'referral_code': code})
          .eq('user_id', userId);

      return code;
    } catch (e) {
      debugPrint('ReferralService: Error generating referral code - $e');
      rethrow;
    }
  }

  /// Apply a referral code when a new user signs up
  Future<bool> applyReferralCode(String newUserId, String referralCode) async {
    try {
      // Find the referral code record
      final referralCodeData = await _client
          .from('referral_codes')
          .select('id, user_id, is_active, max_uses, current_uses, expires_at')
          .eq('code', referralCode.toUpperCase())
          .maybeSingle();

      if (referralCodeData == null) {
        debugPrint('ReferralService: Invalid referral code: $referralCode');
        return false;
      }

      final referrerId = referralCodeData['user_id'] as String;
      final referralCodeId = referralCodeData['id'] as String;

      // Prevent self-referral
      if (referrerId == newUserId) {
        debugPrint('ReferralService: Cannot refer yourself');
        return false;
      }

      // Check if code is active
      if (referralCodeData['is_active'] == false) {
        debugPrint('ReferralService: Referral code is inactive');
        return false;
      }

      // Check expiry
      final expiresAt = referralCodeData['expires_at'] as String?;
      if (expiresAt != null &&
          DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) == true) {
        debugPrint('ReferralService: Referral code has expired');
        return false;
      }

      // Check max uses
      final maxUses = referralCodeData['max_uses'] as int?;
      final currentUses = referralCodeData['current_uses'] as int? ?? 0;
      if (maxUses != null && currentUses >= maxUses) {
        debugPrint('ReferralService: Referral code has reached max uses');
        return false;
      }

      // Check if this user was already referred
      final existingReferral = await _client
          .from('referrals')
          .select('id')
          .eq('referred_id', newUserId)
          .maybeSingle();

      if (existingReferral != null) {
        debugPrint('ReferralService: User $newUserId was already referred');
        return false;
      }

      // Record the referral using the new schema columns
      await _client.from('referrals').insert({
        'referred_id': newUserId,
        'referral_code_id': referralCodeId,
        'status': 'pending',
        'registration_completed': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Increment usage count on the code
      await _client
          .from('referral_codes')
          .update({'current_uses': currentUses + 1})
          .eq('id', referralCodeId);

      // Store referred_by on the new user's profile
      await _client
          .from('profiles')
          .update({'referred_by': referrerId})
          .eq('user_id', newUserId);

      debugPrint(
        'ReferralService: Recorded referral from $referrerId to $newUserId',
      );
      return true;
    } catch (e) {
      debugPrint('ReferralService: Error applying referral code - $e');
      return false;
    }
  }

  /// Complete a referral and award ROOK when the referred user gets verified.
  /// Call this when a new user completes identity verification.
  Future<bool> completeReferral(String referredUserId) async {
    try {
      // Find the pending referral — join through referral_codes to get referrer
      final referral = await _client
          .from('referrals')
          .select('id, referral_code_id, referral_codes(user_id, reward_amount)')
          .eq('referred_id', referredUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (referral == null) {
        debugPrint(
          'ReferralService: No pending referral found for user $referredUserId',
        );
        return false;
      }

      final referralId = referral['id'] as String;
      final codeData = referral['referral_codes'] as Map<String, dynamic>?;
      if (codeData == null) {
        debugPrint('ReferralService: No referral code data found');
        return false;
      }

      final referrerId = codeData['user_id'] as String;
      final rewardAmount = (codeData['reward_amount'] as num?)?.toDouble() ?? 10.0;

      // Mark as verified (identity_verified milestone)
      await _client
          .from('referrals')
          .update({
            'status': 'rewarded',
            'identity_verified': true,
            'referrer_reward_amount': rewardAmount,
            'referred_rewarded_at': DateTime.now().toIso8601String(),
            'verified_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', referralId);

      // Award ROO to the referrer
      await _walletRepo.earnRoo(
        userId: referrerId,
        activityType: RookenActivityType.referral,
        metadata: {
          'referred_user_id': referredUserId,
          'reward_amount': rewardAmount,
          'completion_date': DateTime.now().toIso8601String(),
        },
      );

      debugPrint(
        'ReferralService: Completed referral — awarded $rewardAmount ROO to $referrerId',
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
      // Get user's referral code id first
      final codeRow = await _client
          .from('referral_codes')
          .select('id, current_uses, reward_amount')
          .eq('user_id', userId)
          .maybeSingle();

      if (codeRow == null) {
        return {
          'total_referrals': 0,
          'completed_referrals': 0,
          'pending_referrals': 0,
          'total_earned': 0.0,
        };
      }

      final codeId = codeRow['id'] as String;
      final rewardAmount = (codeRow['reward_amount'] as num?)?.toDouble() ?? 10.0;

      final referrals = await _client
          .from('referrals')
          .select('status, referrer_reward_amount')
          .eq('referral_code_id', codeId);

      final list = referrals as List;
      final total = list.length;
      final completed = list.where((r) => r['status'] == 'rewarded').length;
      final pending = list.where((r) => r['status'] == 'pending').length;
      final totalEarned = list
          .where((r) => r['status'] == 'rewarded')
          .fold<double>(
            0.0,
            (sum, r) =>
                sum + ((r['referrer_reward_amount'] as num?)?.toDouble() ?? rewardAmount),
          );

      return {
        'total_referrals': total,
        'completed_referrals': completed,
        'pending_referrals': pending,
        'total_earned': totalEarned,
      };
    } catch (e) {
      debugPrint('ReferralService: Error getting referral stats - $e');
      return {
        'total_referrals': 0,
        'completed_referrals': 0,
        'pending_referrals': 0,
        'total_earned': 0.0,
      };
    }
  }

  /// Get user's referral code string
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
