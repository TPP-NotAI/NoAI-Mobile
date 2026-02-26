import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user.dart' as app_models;
import '../services/activity_log_service.dart';
import 'notification_repository.dart';

/// Repository for managing follow relationships in Supabase.
class FollowRepository {
  final SupabaseClient _client;
  final _notificationRepository = NotificationRepository();
  final _activityLogService = ActivityLogService();

  FollowRepository(this._client);

  /// Check if the current user is following a specific user.
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('follower_id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('FollowRepository: Error checking follow status - $e');
      return false;
    }
  }

  /// Follow a user.
  Future<bool> followUser(String followerId, String followingId) async {
    try {
      await _client.from(SupabaseConfig.followsTable).insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
      unawaited(
        _activityLogService.log(
          userId: followerId,
          activityType: 'follow',
          targetType: 'user',
          targetId: followingId,
          description: 'Followed a user',
        ),
      );

      // Notify followed user
      try {
        await _notificationRepository.createNotification(
          userId: followingId,
          type: 'follow',
          actorId: followerId,
        );
      } catch (e) {
        debugPrint(
          'FollowRepository: Error creating notification for follow - $e',
        );
      }

      return true;
    } catch (e) {
      debugPrint('FollowRepository: Error following user - $e');
      return false;
    }
  }

  /// Unfollow a user.
  Future<bool> unfollowUser(String followerId, String followingId) async {
    try {
      await _client
          .from(SupabaseConfig.followsTable)
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
      unawaited(
        _activityLogService.log(
          userId: followerId,
          activityType: 'unfollow',
          targetType: 'user',
          targetId: followingId,
          description: 'Unfollowed a user',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('FollowRepository: Error unfollowing user - $e');
      return false;
    }
  }

  /// Get the count of users that a specific user is following.
  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('follower_id')
          .eq('follower_id', userId);

      return response.length;
    } catch (e) {
      debugPrint('FollowRepository: Error getting following count - $e');
      return 0;
    }
  }

  /// Get the list of users who follow a specific user.
  Future<List<app_models.User>> getFollowers(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('follower_id, ${SupabaseConfig.profilesTable}!follows_follower_id_fkey(*, ${SupabaseConfig.walletsTable}(*))')
          .eq('following_id', userId);

      return (response as List).map((row) {
        final profile = row[SupabaseConfig.profilesTable] as Map<String, dynamic>;
        final wallet = profile[SupabaseConfig.walletsTable];
        return app_models.User.fromSupabase(profile, wallet: wallet);
      }).toList();
    } catch (e) {
      debugPrint('FollowRepository: Error getting followers list - $e');
      return [];
    }
  }

  /// Get the list of users that a specific user is following.
  Future<List<app_models.User>> getFollowing(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('following_id, ${SupabaseConfig.profilesTable}!follows_following_id_fkey(*, ${SupabaseConfig.walletsTable}(*))')
          .eq('follower_id', userId);

      return (response as List).map((row) {
        final profile = row[SupabaseConfig.profilesTable] as Map<String, dynamic>;
        final wallet = profile[SupabaseConfig.walletsTable];
        return app_models.User.fromSupabase(profile, wallet: wallet);
      }).toList();
    } catch (e) {
      debugPrint('FollowRepository: Error getting following list - $e');
      return [];
    }
  }

  /// Get the count of followers for a specific user.
  Future<int> getFollowersCount(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('following_id')
          .eq('following_id', userId);

      return response.length;
    } catch (e) {
      debugPrint('FollowRepository: Error getting followers count - $e');
      return 0;
    }
  }
}
