import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/comment.dart';
import '../services/supabase_service.dart';

import 'notification_repository.dart';
import 'mention_repository.dart';

/// Repository for comment-related Supabase operations.
class CommentRepository {
  final _client = SupabaseService().client;
  final _notificationRepository = NotificationRepository();
  final _mentionRepository = MentionRepository();

  /// Fetch comments for a post.
  /// Optionally filter out comments from blocked users.
  /// Respects privacy settings: filters comments based on author's comments_visibility setting.
  Future<List<Comment>> getCommentsForPost(
    String postId, {
    String? currentUserId,
    Set<String> blockedUserIds = const {},
    Set<String> blockedByUserIds = const {},
    Set<String> mutedUserIds = const {},
  }) async {
    debugPrint(
      'CommentRepository: Fetching comments for post=$postId, currentUserId=$currentUserId',
    );

    final response = await _client
        .from(SupabaseConfig.commentsTable)
        .select('''
          *,
          profiles!comments_author_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            comments_visibility
          ),
          reactions!reactions_comment_id_fkey (
            user_id,
            reaction_type
          )
        ''')
        .eq('post_id', postId)
        .isFilter('parent_comment_id', null) // Only top-level comments
        .order('created_at', ascending: true);

    debugPrint('CommentRepository: Raw response = $response');

    // Get following list for privacy filtering
    final followingIds = currentUserId != null
        ? await _getFollowingIds(currentUserId)
        : <String>{};

    // Fetch replies for each comment, filtering out blocked users
    final comments = <Comment>[];
    for (final json in response) {
      final authorId = json['author_id'] as String?;
      final profile = json['profiles'] as Map<String, dynamic>?;
      final commentsVisibility = profile?['comments_visibility'] as String?;

      // Skip comments from blocked users or users who blocked the current user OR muted users
      if (authorId != null &&
          (blockedUserIds.contains(authorId) ||
              blockedByUserIds.contains(authorId) ||
              mutedUserIds.contains(authorId))) {
        continue;
      }

      // Check privacy settings
      if (!_canViewComment(
        authorId: authorId,
        commentsVisibility: commentsVisibility,
        currentUserId: currentUserId,
        followingIds: followingIds,
      )) {
        continue;
      }

      debugPrint(
        'CommentRepository: Comment ${json['id']} reactions = ${json['reactions']}',
      );
      final comment = Comment.fromSupabase(json, currentUserId: currentUserId);
      debugPrint(
        'CommentRepository: Parsed comment isLiked = ${comment.isLiked}, likes = ${comment.likes}',
      );
      final replies = await _getReplies(
        json['id'],
        currentUserId: currentUserId,
        blockedUserIds: blockedUserIds,
        blockedByUserIds: blockedByUserIds,
        mutedUserIds: mutedUserIds,
        followingIds: followingIds,
      );
      comments.add(
        comment.copyWith(replies: replies.isNotEmpty ? replies : null),
      );
    }

    return comments;
  }

  /// Check if current user can view a comment based on privacy settings.
  bool _canViewComment({
    required String? authorId,
    required String? commentsVisibility,
    required String? currentUserId,
    required Set<String> followingIds,
  }) {
    // Author can always see their own comments
    if (authorId != null && authorId == currentUserId) {
      return true;
    }

    final visibility = commentsVisibility ?? 'everyone';

    switch (visibility) {
      case 'everyone':
        return true;
      case 'followers':
        return currentUserId != null && followingIds.contains(authorId);
      case 'private':
        return false; // Only author can see
      default:
        return true; // Default to public if unknown setting
    }
  }

  /// Get list of user IDs that the current user follows.
  Future<Set<String>> _getFollowingIds(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('following_id')
          .eq('follower_id', userId);

      return (response as List)
          .map((row) => row['following_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('CommentRepository: Error fetching following list - $e');
      return {};
    }
  }

  /// Fetch replies for a comment.
  /// Optionally filter out replies from blocked users.
  Future<List<Comment>> _getReplies(
    String parentCommentId, {
    String? currentUserId,
    Set<String> blockedUserIds = const {},
    Set<String> blockedByUserIds = const {},
    Set<String> mutedUserIds = const {},
    Set<String> followingIds = const {},
  }) async {
    final response = await _client
        .from(SupabaseConfig.commentsTable)
        .select('''
          *,
          profiles!comments_author_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            comments_visibility
          ),
          reactions!reactions_comment_id_fkey (
            user_id,
            reaction_type
          )
        ''')
        .eq('parent_comment_id', parentCommentId)
        .order('created_at', ascending: true);

    // Filter out replies from blocked users
    final filteredReplies = <Comment>[];
    for (final json in response) {
      final authorId = json['author_id'] as String?;
      final profile = json['profiles'] as Map<String, dynamic>?;
      final commentsVisibility = profile?['comments_visibility'] as String?;

      // Skip replies from blocked users or users who blocked the current user OR muted users
      if (authorId != null &&
          (blockedUserIds.contains(authorId) ||
              blockedByUserIds.contains(authorId) ||
              mutedUserIds.contains(authorId))) {
        continue;
      }

      // Check privacy settings
      if (!_canViewComment(
        authorId: authorId,
        commentsVisibility: commentsVisibility,
        currentUserId: currentUserId,
        followingIds: followingIds,
      )) {
        continue;
      }

      filteredReplies.add(
        Comment.fromSupabase(json, currentUserId: currentUserId),
      );
    }

    return filteredReplies;
  }

  /// Add a comment to a post.
  Future<Comment?> addComment({
    required String postId,
    required String authorId,
    required String body,
    String? parentCommentId,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final insertData = {
      'post_id': postId,
      'author_id': authorId,
      'body': body,
      'parent_comment_id': parentCommentId,
    };

    // Add media fields if provided
    if (mediaUrl != null) {
      insertData['media_url'] = mediaUrl;
    }
    if (mediaType != null) {
      insertData['media_type'] = mediaType;
    }

    final response = await _client
        .from(SupabaseConfig.commentsTable)
        .insert(insertData)
        .select('''
          *,
          profiles!comments_author_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url
          )
        ''')
        .single();

    final comment = Comment.fromSupabase(response, currentUserId: authorId);

    // Notify post author
    try {
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id, title, body')
          .eq('id', postId)
          .single();

      final postAuthorId = post['author_id'] as String;

      // Only notify if author is not the commenter
      if (postAuthorId != authorId) {
        final postTitle = post['title'] as String?;
        final postBody = post['body'] as String?;
        final notificationBody = postTitle != null && postTitle.isNotEmpty
            ? 'Someone commented on your post: "$postTitle"'
            : 'Someone commented on your post: "${postBody?.substring(0, (postBody.length > 50 ? 50 : postBody.length)) ?? ''}..."';

        await _notificationRepository.createNotification(
          userId: postAuthorId,
          type: 'comment', // Using generic 'comment' type for post comments too
          title: 'New Comment',
          body: notificationBody,
          actorId: authorId,
          postId: postId,
          commentId: comment.id,
        );
      }

      // Notify parent comment author if it's a reply
      if (parentCommentId != null) {
        final parentComment = await _client
            .from(SupabaseConfig.commentsTable)
            .select('author_id, body')
            .eq('id', parentCommentId)
            .single();

        final parentAuthorId = parentComment['author_id'] as String;

        // Only notify if parent author is not the commenter AND not the post author (avoid double notification if they are same)
        // Actually, some platforms notify for both. Let's notify unless it's self.
        if (parentAuthorId != authorId && parentAuthorId != postAuthorId) {
          await _notificationRepository.createNotification(
            userId: parentAuthorId,
            type: 'reply',
            title: 'New Reply',
            body:
                'Someone replied to your comment: "${parentComment['body'] ?? ''}"',
            actorId: authorId,
            postId: postId,
            commentId: comment.id,
          );
        }
      }
    } catch (e) {
      debugPrint(
        'CommentRepository: Error creating notification for comment - $e',
      );
    }

    // Handle mentions
    try {
      final mentions = _mentionRepository.extractMentions(body);
      if (mentions.isNotEmpty) {
        final mentionedUserIds = await _mentionRepository.resolveUsernamesToIds(
          mentions,
        );
        if (mentionedUserIds.isNotEmpty) {
          await _mentionRepository.addMentionsToComment(
            commentId: comment.id,
            mentionedUserIds: mentionedUserIds,
          );
        }
      }
    } catch (e) {
      debugPrint('CommentRepository: Error handling mentions - $e');
    }

    return comment;
  }

  /// Upload media for a comment and return the public URL.
  Future<String?> uploadCommentMedia({
    required File file,
    required String userId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last.toLowerCase();
      final fileName = '${userId}_$timestamp.$extension';
      final storagePath = 'comments/$userId/$fileName';

      // Determine content type
      String contentType;
      final isVideo = ['mp4', 'mov', 'avi', 'webm'].contains(extension);
      if (isVideo) {
        contentType = extension == 'mov'
            ? 'video/quicktime'
            : 'video/$extension';
      } else {
        contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
      }

      // Upload to Supabase Storage
      await _client.storage
          .from(SupabaseConfig.commentMediaBucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(SupabaseConfig.commentMediaBucket)
          .getPublicUrl(storagePath);
      debugPrint('CommentRepository: Uploaded comment media to $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('CommentRepository: Error uploading comment media - $e');
      return null;
    }
  }

  /// Get media type from file extension.
  String getMediaType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'webm'].contains(extension)) {
      return 'video';
    }
    return 'image';
  }

  /// Delete a comment.
  /// Validates ownership before deleting.
  Future<bool> deleteComment(String commentId, {required String currentUserId}) async {
    try {
      // RLS enforces this at DB level, but we check here for a clear error message
      final comment = await _client
          .from(SupabaseConfig.commentsTable)
          .select('author_id')
          .eq('id', commentId)
          .maybeSingle();

      if (comment == null) {
        debugPrint('CommentRepository: Comment not found');
        return false;
      }

      if (comment['author_id'] != currentUserId) {
        debugPrint('CommentRepository: Unauthorized - user does not own this comment');
        return false;
      }

      await _client
          .from(SupabaseConfig.commentsTable)
          .delete()
          .eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('CommentRepository: Error deleting comment - $e');
      return false;
    }
  }

  /// Update a comment's content.
  /// Validates ownership before updating.
  Future<Comment?> updateComment({
    required String commentId,
    required String currentUserId,
    required String newBody,
    String? mediaUrl,
    String? mediaType,
  }) async {
    try {
      // RLS enforces this at DB level, but we check here for a clear error message
      final existing = await _client
          .from(SupabaseConfig.commentsTable)
          .select('author_id')
          .eq('id', commentId)
          .maybeSingle();

      if (existing == null || existing['author_id'] != currentUserId) {
        debugPrint('CommentRepository: Unauthorized or comment not found');
        return null;
      }

      final updates = <String, dynamic>{
        'body': newBody,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (mediaUrl != null) updates['media_url'] = mediaUrl;
      if (mediaType != null) updates['media_type'] = mediaType;

      final response = await _client
          .from(SupabaseConfig.commentsTable)
          .update(updates)
          .eq('id', commentId)
          .select('''
            *,
            profiles!comments_author_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              comments_visibility
            ),
            reactions!reactions_comment_id_fkey (
              user_id,
              reaction_type
            )
          ''')
          .single();

      return Comment.fromSupabase(response, currentUserId: currentUserId);
    } catch (e) {
      debugPrint('CommentRepository: Error updating comment - $e');
      return null;
    }
  }

  /// Get comment count for a post.
  Future<int> getCommentCount(String postId) async {
    final response = await _client
        .from(SupabaseConfig.commentsTable)
        .select('id')
        .eq('post_id', postId);

    return (response as List).length;
  }
}
