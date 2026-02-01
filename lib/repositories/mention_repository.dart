import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import 'notification_repository.dart';

/// Repository for handling user mentions in posts and comments.
class MentionRepository {
  final _client = SupabaseService().client;

  final _notificationRepository = NotificationRepository();

  /// Add mentions for a post.
  Future<bool> addMentionsToPost({
    required String postId,
    required List<String> mentionedUserIds,
  }) async {
    try {
      for (final userId in mentionedUserIds) {
        await _client.from(SupabaseConfig.mentionsTable).insert({
          'post_id': postId,
          'mentioned_user_id': userId,
        });
      }

      // Fetch post details for notification
      try {
        final post = await _client
            .from(SupabaseConfig.postsTable)
            .select('author_id, title, body')
            .eq('id', postId)
            .single();

        final authorId = post['author_id'] as String;
        final postTitle = post['title'] as String?;
        final postBody = post['body'] as String?;
        final notificationBody = postTitle != null && postTitle.isNotEmpty
            ? 'Mentioned you in a post: "$postTitle"'
            : 'Mentioned you in a post: "${postBody?.substring(0, (postBody.length > 50 ? 50 : postBody.length)) ?? ''}..."';

        for (final userId in mentionedUserIds) {
          // Don't notify if user mentions themselves (unlikely but possible)
          if (userId == authorId) continue;

          await _notificationRepository.createNotification(
            userId: userId,
            type: 'mention',
            title: 'New Mention',
            body: notificationBody,
            actorId: authorId,
            postId: postId,
          );
        }
      } catch (e) {
        debugPrint(
          'MentionRepository: Error creating notifications for post mentions - $e',
        );
      }

      return true;
    } catch (e) {
      debugPrint('MentionRepository: Error adding mentions to post - $e');
      return false;
    }
  }

  /// Add mentions for a comment.
  Future<bool> addMentionsToComment({
    required String commentId,
    required List<String> mentionedUserIds,
  }) async {
    try {
      for (final userId in mentionedUserIds) {
        await _client.from(SupabaseConfig.mentionsTable).insert({
          'comment_id': commentId,
          'mentioned_user_id': userId,
        });
      }

      // Fetch comment details for notification
      try {
        final comment = await _client
            .from(SupabaseConfig.commentsTable)
            .select('author_id, body, post_id')
            .eq('id', commentId)
            .single();

        final authorId = comment['author_id'] as String;
        final body = comment['body'] as String?;
        final postId = comment['post_id'] as String;
        final notificationBody =
            'Mentioned you in a comment: "${body?.substring(0, (body.length > 50 ? 50 : body.length)) ?? ''}..."';

        for (final userId in mentionedUserIds) {
          // Don't notify if user mentions themselves
          if (userId == authorId) continue;

          await _notificationRepository.createNotification(
            userId: userId,
            type: 'mention',
            title: 'New Mention',
            body: notificationBody,
            actorId: authorId,
            postId: postId,
            commentId: commentId,
          );
        }
      } catch (e) {
        debugPrint(
          'MentionRepository: Error creating notifications for comment mentions - $e',
        );
      }

      return true;
    } catch (e) {
      debugPrint('MentionRepository: Error adding mentions to comment - $e');
      return false;
    }
  }

  /// Remove all mentions from a post.
  Future<bool> removeMentionsFromPost(String postId) async {
    try {
      await _client
          .from(SupabaseConfig.mentionsTable)
          .delete()
          .eq('post_id', postId);
      return true;
    } catch (e) {
      debugPrint('MentionRepository: Error removing mentions from post - $e');
      return false;
    }
  }

  /// Search for users by username prefix (for @mention autocomplete).
  /// Filters out blocked and muted users.
  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    int limit = 10,
    Set<String> blockedUserIds = const {},
    Set<String> blockedByUserIds = const {},
    Set<String> mutedUserIds = const {},
  }) async {
    try {
      final normalizedQuery = query.toLowerCase().trim();
      if (normalizedQuery.isEmpty) return [];

      final allExcluded = {
        ...blockedUserIds,
        ...blockedByUserIds,
        ...mutedUserIds,
      };

      final response = await _client
          .from(SupabaseConfig.profilesTable)
          .select('user_id, username, display_name, avatar_url')
          .or(
            'username.ilike.${normalizedQuery}%,display_name.ilike.${normalizedQuery}%',
          )
          .limit(
            limit + allExcluded.length,
          ); // Fetch extra to compensate for filtering

      // Filter out blocked and muted users
      final filtered = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((user) => !allExcluded.contains(user['user_id']))
          .take(limit)
          .toList();

      return filtered;
    } catch (e) {
      debugPrint('MentionRepository: Error searching users - $e');
      return [];
    }
  }

  /// Extract @mentions from text content (e.g., "@username").
  List<String> extractMentions(String content) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  /// Resolve usernames to user IDs.
  Future<List<String>> resolveUsernamesToIds(List<String> usernames) async {
    if (usernames.isEmpty) return [];

    try {
      final response = await _client
          .from(SupabaseConfig.profilesTable)
          .select('user_id')
          .inFilter('username', usernames);

      return (response as List<dynamic>)
          .map((r) => r['user_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('MentionRepository: Error resolving usernames - $e');
      return [];
    }
  }
}
