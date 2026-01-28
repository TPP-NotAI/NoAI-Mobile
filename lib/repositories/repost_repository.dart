import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';

/// Repository for repost operations.
class RepostRepository {
  final _client = SupabaseService().client;

  /// Toggle repost on a post.
  /// Returns true if reposted, false if unreposted.
  Future<bool> toggleRepost({
    required String postId,
    required String userId,
  }) async {
    debugPrint('RepostRepository: Toggling repost for post=$postId, user=$userId');

    // Check if repost exists
    final existing = await _client
        .from(SupabaseConfig.repostsTable)
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    debugPrint('RepostRepository: Existing repost = $existing');

    if (existing != null) {
      // Remove repost
      debugPrint('RepostRepository: Removing repost');
      await _client
          .from(SupabaseConfig.repostsTable)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return false;
    } else {
      // Add repost
      debugPrint('RepostRepository: Adding repost');
      await _client.from(SupabaseConfig.repostsTable).insert({
        'post_id': postId,
        'user_id': userId,
      });
      debugPrint('RepostRepository: Insert successful');
      return true;
    }
  }

  /// Check if user has reposted a post.
  Future<bool> isReposted({
    required String postId,
    required String userId,
  }) async {
    final response = await _client
        .from(SupabaseConfig.repostsTable)
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  /// Get repost count for a post.
  Future<int> getRepostCount({required String postId}) async {
    final response = await _client
        .from(SupabaseConfig.repostsTable)
        .select('id')
        .eq('post_id', postId);

    return (response as List).length;
  }

  /// Get all reposted post IDs for a user.
  Future<Set<String>> getUserRepostIds({required String userId}) async {
    final response = await _client
        .from(SupabaseConfig.repostsTable)
        .select('post_id')
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((r) => r['post_id'] as String)
        .toSet();
  }

  /// Get repost counts for multiple posts.
  Future<Map<String, int>> getRepostCounts({required List<String> postIds}) async {
    if (postIds.isEmpty) return {};

    final response = await _client
        .from(SupabaseConfig.repostsTable)
        .select('post_id')
        .inFilter('post_id', postIds);

    final counts = <String, int>{};
    for (final r in response as List<dynamic>) {
      final postId = r['post_id'] as String;
      counts[postId] = (counts[postId] ?? 0) + 1;
    }
    return counts;
  }
}
