import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import 'notification_repository.dart';

/// Repository for reaction (like/unlike) operations.
/// Schema constraint: reactions can be on EITHER a post OR a comment, not both.
/// - Post reaction: post_id NOT NULL, comment_id NULL
/// - Comment reaction: post_id NULL, comment_id NOT NULL
class ReactionRepository {
  final _client = SupabaseService().client;
  final _notificationRepository = NotificationRepository();

  /// Toggle like on a comment.
  /// Returns true if liked, false if unliked.
  Future<bool> toggleCommentLike({
    required String commentId,
    required String userId,
  }) async {
    debugPrint(
      'ReactionRepository: Toggling like for comment=$commentId, user=$userId',
    );

    // Check if reaction exists (comment reactions have post_id = NULL)
    final existing = await _client
        .from(SupabaseConfig.reactionsTable)
        .select('user_id')
        .isFilter('post_id', null)
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .eq('reaction_type', 'like')
        .maybeSingle();

    debugPrint('ReactionRepository: Existing reaction = $existing');

    if (existing != null) {
      // Unlike - delete the reaction
      debugPrint('ReactionRepository: Deleting existing reaction');
      await _client
          .from(SupabaseConfig.reactionsTable)
          .delete()
          .isFilter('post_id', null)
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .eq('reaction_type', 'like');
      return false;
    } else {
      // Like - insert new reaction (post_id must be NULL for comment reactions)
      debugPrint('ReactionRepository: Inserting new reaction');
      await _client.from(SupabaseConfig.reactionsTable).insert({
        'post_id': null,
        'comment_id': commentId,
        'user_id': userId,
        'reaction_type': 'like',
      });
      debugPrint('ReactionRepository: Insert successful');

      // Fetch comment author to notify
      try {
        final comment = await _client
            .from(SupabaseConfig.commentsTable)
            .select('author_id, body')
            .eq('id', commentId)
            .single();

        await _notificationRepository.createNotification(
          userId: comment['author_id'],
          type: 'like',
          title: 'New Like',
          body: 'Someone liked your comment: "${comment['body']}"',
          actorId: userId,
          commentId: commentId,
        );
      } catch (e) {
        debugPrint(
          'ReactionRepository: Error creating notification for comment like - $e',
        );
      }

      return true;
    }
  }

  /// Toggle like on a post.
  /// Returns true if liked, false if unliked.
  Future<bool> togglePostLike({
    required String postId,
    required String userId,
  }) async {
    debugPrint(
      'ReactionRepository: Toggling like for post=$postId, user=$userId',
    );

    // Check if reaction exists (post reactions have comment_id = NULL)
    final existing = await _client
        .from(SupabaseConfig.reactionsTable)
        .select('user_id')
        .eq('post_id', postId)
        .isFilter('comment_id', null)
        .eq('user_id', userId)
        .eq('reaction_type', 'like')
        .maybeSingle();

    debugPrint('ReactionRepository: Existing reaction = $existing');

    if (existing != null) {
      // Unlike - delete the reaction
      debugPrint('ReactionRepository: Deleting existing reaction');
      await _client
          .from(SupabaseConfig.reactionsTable)
          .delete()
          .eq('post_id', postId)
          .isFilter('comment_id', null)
          .eq('user_id', userId)
          .eq('reaction_type', 'like');
      return false;
    } else {
      // Like - insert new reaction (comment_id must be NULL for post reactions)
      debugPrint('ReactionRepository: Inserting new reaction');
      await _client.from(SupabaseConfig.reactionsTable).insert({
        'post_id': postId,
        'comment_id': null,
        'user_id': userId,
        'reaction_type': 'like',
      });
      debugPrint('ReactionRepository: Insert successful');

      // Fetch post author to notify
      try {
        final post = await _client
            .from(SupabaseConfig.postsTable)
            .select('author_id, title, body')
            .eq('id', postId)
            .single();

        final postTitle = post['title'] as String?;
        final postBody = post['body'] as String?;
        final notificationBody = postTitle != null && postTitle.isNotEmpty
            ? 'Someone liked your post: "$postTitle"'
            : 'Someone liked your post: "${postBody?.substring(0, (postBody.length > 50 ? 50 : postBody.length)) ?? ''}..."';

        await _notificationRepository.createNotification(
          userId: post['author_id'],
          type: 'like',
          title: 'New Like',
          body: notificationBody,
          actorId: userId,
          postId: postId,
        );
      } catch (e) {
        debugPrint(
          'ReactionRepository: Error creating notification for post like - $e',
        );
      }

      return true;
    }
  }

  /// Check if user has liked a comment.
  Future<bool> hasLikedComment({
    required String commentId,
    required String userId,
  }) async {
    final response = await _client
        .from(SupabaseConfig.reactionsTable)
        .select('user_id')
        .isFilter('post_id', null)
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .eq('reaction_type', 'like')
        .maybeSingle();

    return response != null;
  }

  /// Get like count for a comment.
  Future<int> getCommentLikeCount({required String commentId}) async {
    final response = await _client
        .from(SupabaseConfig.reactionsTable)
        .select('user_id')
        .isFilter('post_id', null)
        .eq('comment_id', commentId)
        .eq('reaction_type', 'like');

    return (response as List).length;
  }
}
