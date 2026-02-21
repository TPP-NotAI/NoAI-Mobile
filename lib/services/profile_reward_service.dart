import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';

/// Helper service to track and reward profile completion milestones
class ProfileRewardService {
  final _client = SupabaseService().client;
  final _walletRepo = WalletRepository();

  /// Check if profile is complete and award ROOK if not already rewarded
  /// Profile is considered complete if user has:
  /// - Display name
  /// - Bio
  /// - Avatar
  /// - At least one social link
  Future<bool> checkAndRewardProfileCompletion(String userId) async {
    try {
      // Check if already rewarded
      final existingReward = await _client
          .from('roocoin_transactions')
          .select('id')
          .eq('to_user_id', userId)
          .contains('metadata', {
            'activityType': RookenActivityType.profileComplete,
          })
          .maybeSingle();

      if (existingReward != null) {
        debugPrint(
          'ProfileRewardService: User $userId already rewarded for profile completion',
        );
        return false;
      }

      // Fetch profile data
      final profile = await _client
          .from(SupabaseConfig.profilesTable)
          .select('display_name, bio, avatar_url')
          .eq('user_id', userId)
          .single();

      // Fetch social links
      final links = await _client
          .from('profile_links')
          .select('id')
          .eq('user_id', userId);

      // Check completion criteria
      final hasDisplayName =
          (profile['display_name'] as String?)?.trim().isNotEmpty ?? false;
      final hasBio = (profile['bio'] as String?)?.trim().isNotEmpty ?? false;
      final hasAvatar =
          (profile['avatar_url'] as String?)?.trim().isNotEmpty ?? false;
      final hasSocialLink = (links as List).isNotEmpty;

      final isComplete = hasDisplayName && hasBio && hasAvatar && hasSocialLink;

      if (isComplete) {
        // Award 5 ROOK for profile completion
        await _walletRepo.earnRoo(
          userId: userId,
          activityType: RookenActivityType.profileComplete,
          metadata: {'completion_date': DateTime.now().toIso8601String()},
        );
        debugPrint(
          'ProfileRewardService: Awarded 5 ROOK to $userId for profile completion',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint(
        'ProfileRewardService: Error checking profile completion - $e',
      );
      return false;
    }
  }

  /// Get profile completion percentage (0-100)
  Future<int> getProfileCompletionPercentage(String userId) async {
    try {
      final profile = await _client
          .from(SupabaseConfig.profilesTable)
          .select('display_name, bio, avatar_url')
          .eq('user_id', userId)
          .single();

      final links = await _client
          .from('profile_links')
          .select('id')
          .eq('user_id', userId);

      int completed = 0;
      const int total = 4;

      if ((profile['display_name'] as String?)?.trim().isNotEmpty ?? false)
        completed++;
      if ((profile['bio'] as String?)?.trim().isNotEmpty ?? false) completed++;
      if ((profile['avatar_url'] as String?)?.trim().isNotEmpty ?? false)
        completed++;
      if ((links as List).isNotEmpty) completed++;

      return ((completed / total) * 100).round();
    } catch (e) {
      debugPrint(
        'ProfileRewardService: Error getting completion percentage - $e',
      );
      return 0;
    }
  }
}
