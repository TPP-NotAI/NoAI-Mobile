import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Repository for managing user block relationships in Supabase.
class BlockRepository {
  final SupabaseClient _client;

  BlockRepository(this._client);

  /// Check if the current user has blocked a specific user.
  Future<bool> isBlocked(String blockerId, String blockedId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.blocksTable)
          .select('blocker_id')
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('BlockRepository: Error checking block status - $e');
      return false;
    }
  }

  /// Block a user.
  Future<bool> blockUser(String blockerId, String blockedId) async {
    try {
      await _client.from(SupabaseConfig.blocksTable).insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
      return true;
    } catch (e) {
      debugPrint('BlockRepository: Error blocking user - $e');
      return false;
    }
  }

  /// Unblock a user.
  Future<bool> unblockUser(String blockerId, String blockedId) async {
    try {
      await _client
          .from(SupabaseConfig.blocksTable)
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
      return true;
    } catch (e) {
      debugPrint('BlockRepository: Error unblocking user - $e');
      return false;
    }
  }

  /// Get list of blocked user IDs (users that this user has blocked).
  Future<List<String>> getBlockedUserIds(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.blocksTable)
          .select('blocked_id')
          .eq('blocker_id', userId);

      return (response as List)
          .map((row) => row['blocked_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('BlockRepository: Error getting blocked users - $e');
      return [];
    }
  }

  /// Get list of user IDs who have blocked this user.
  Future<List<String>> getBlockedByUserIds(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.blocksTable)
          .select('blocker_id')
          .eq('blocked_id', userId);

      return (response as List)
          .map((row) => row['blocker_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('BlockRepository: Error getting blocked-by users - $e');
      return [];
    }
  }

  /// Check if a user has blocked the current user.
  Future<bool> isBlockedBy(String blockerId, String blockedId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.blocksTable)
          .select('blocker_id')
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('BlockRepository: Error checking blocked-by status - $e');
      return false;
    }
  }

  /// Get all block relationships for a user (both blocked and blocked-by).
  /// Returns a map with 'blocked' and 'blockedBy' lists.
  Future<Map<String, List<String>>> getAllBlockRelationships(String userId) async {
    try {
      // Fetch both in parallel
      final results = await Future.wait([
        getBlockedUserIds(userId),
        getBlockedByUserIds(userId),
      ]);

      return {
        'blocked': results[0],
        'blockedBy': results[1],
      };
    } catch (e) {
      debugPrint('BlockRepository: Error getting all block relationships - $e');
      return {'blocked': [], 'blockedBy': []};
    }
  }
}
