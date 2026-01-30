import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import 'notification_repository.dart';

/// Repository for repost operations.
class RepostRepository {
  final _client = SupabaseService().client;
  final _notificationRepository = NotificationRepository();

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

      // Notify the original post author
      try {
        final post = await _client
            .from(SupabaseConfig.postsTable)
            .select('author_id, title, body')
            .eq('id', postId)
            .single();

        final postAuthorId = post['author_id'] as String;
        if (postAuthorId != userId) {
          final postTitle = post['title'] as String?;
          final postBody = post['body'] as String?;
          final preview = postTitle != null && postTitle.isNotEmpty
              ? postTitle
              : (postBody != null && postBody.length > 50
                  ? '${postBody.substring(0, 50)}...'
                  : postBody ?? '');

          await _notificationRepository.createNotification(
            userId: postAuthorId,
            type: 'repost',
            title: 'New Repost',
            body: 'Someone reposted your post: "$preview"',
            actorId: userId,
            postId: postId,
          );
        }
      } catch (e) {
        debugPrint('RepostRepository: Error creating repost notification - $e');
      }

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
