import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'notification_repository.dart';

/// Repository for managing follow relationships in Supabase.
class FollowRepository {
  final SupabaseClient _client;
  final _notificationRepository = NotificationRepository();

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

      // Notify followed user
      try {
        await _notificationRepository.createNotification(
          userId: followingId,
          type: 'follow',
          title: 'New Follower',
          body: 'Started following you',
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
