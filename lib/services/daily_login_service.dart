import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../repositories/wallet_repository.dart';
import '../services/roocoin_service.dart';

/// Service to track daily logins and reward users
class DailyLoginService {
  final _client = SupabaseService().client;
  final _walletRepo = WalletRepository();

  /// Check and reward daily login (1 ROO per day)
  /// Returns true if reward was given, false if already claimed today
  Future<bool> checkAndRewardDailyLogin(String userId) async {
    try {
      final today = DateTime.now().toUtc();
      final todayStart = DateTime.utc(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Check if user already claimed today's reward
      // Check if user already claimed today's reward
      // Filtering in Dart to ensure reliability
      final todaysTxs = await _client
          .from('roocoin_transactions')
          .select('metadata')
          .eq('to_user_id', userId)
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String());

      final existingReward = todaysTxs.any((tx) {
        final metadata = tx['metadata'];
        if (metadata is Map) {
          return metadata['activityType'] == RoocoinActivityType.dailyLogin;
        }
        return false;
      });

      if (existingReward) {
        debugPrint(
          'DailyLoginService: User $userId already claimed daily login reward today',
        );
        return false;
      }

      // Award 1 ROO for daily login
      await _walletRepo.earnRoo(
        userId: userId,
        activityType: RoocoinActivityType.dailyLogin,
        metadata: {
          'login_date': today.toIso8601String(),
          'day_of_week': today.weekday,
        },
      );

      debugPrint('DailyLoginService: Awarded 1 ROO to $userId for daily login');
      return true;
    } catch (e) {
      debugPrint('DailyLoginService: Error checking daily login - $e');
      return false;
    }
  }

  /// Get current login streak (consecutive days)
  Future<int> getLoginStreak(String userId) async {
    try {
      // Get all daily login rewards ordered by date
      final rewards = await _client
          .from('roocoin_transactions')
          .select('created_at')
          .eq('to_user_id', userId)
          .contains('metadata', {
            'activityType': RoocoinActivityType.dailyLogin,
          })
          .order('created_at', ascending: false)
          .limit(365); // Check up to 1 year

      if (rewards.isEmpty) return 0;

      int streak = 0;
      DateTime? lastDate;

      for (final reward in rewards as List) {
        final createdAt = DateTime.parse(
          reward['created_at'] as String,
        ).toUtc();
        final rewardDate = DateTime.utc(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );

        if (lastDate == null) {
          // First reward - check if it's today or yesterday
          final today = DateTime.now().toUtc();
          final todayDate = DateTime.utc(today.year, today.month, today.day);
          final yesterday = todayDate.subtract(const Duration(days: 1));

          if (rewardDate == todayDate || rewardDate == yesterday) {
            streak = 1;
            lastDate = rewardDate;
          } else {
            break; // Streak is broken
          }
        } else {
          // Check if this reward is exactly 1 day before the last one
          final expectedDate = lastDate.subtract(const Duration(days: 1));
          if (rewardDate == expectedDate) {
            streak++;
            lastDate = rewardDate;
          } else {
            break; // Streak is broken
          }
        }
      }

      return streak;
    } catch (e) {
      debugPrint('DailyLoginService: Error getting login streak - $e');
      return 0;
    }
  }

  /// Check if user can claim today's reward
  Future<bool> canClaimToday(String userId) async {
    try {
      final today = DateTime.now().toUtc();
      final todayStart = DateTime.utc(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todaysTxs = await _client
          .from('roocoin_transactions')
          .select('metadata')
          .eq('to_user_id', userId)
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String());

      final existingReward = todaysTxs.any((tx) {
        final metadata = tx['metadata'];
        if (metadata is Map) {
          return metadata['activityType'] == RoocoinActivityType.dailyLogin;
        }
        return false;
      });

      return !existingReward;
    } catch (e) {
      debugPrint('DailyLoginService: Error checking if can claim - $e');
      return false;
    }
  }
}
