import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/comment.dart';
import '../models/ai_detection_result.dart';
import '../services/supabase_service.dart';
import '../services/ai_detection_service.dart';

import 'notification_repository.dart';
import 'mention_repository.dart';
import 'wallet_repository.dart';
import '../services/rooken_service.dart';

/// Repository for comment-related Supabase operations.
class CommentRepository {
  final _client = SupabaseService().client;
  final _notificationRepository = NotificationRepository();
  final _mentionRepository = MentionRepository();
  final _aiDetectionService = AiDetectionService();

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
        .eq('status', 'published')
        .isFilter('parent_comment_id', null) // Only top-level comments
        .order('created_at', ascending: false);

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
        .eq('status', 'published')
        .order('created_at', ascending: false);

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
  Future<bool> deleteComment(
    String commentId, {
    required String currentUserId,
  }) async {
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
        debugPrint(
          'CommentRepository: Unauthorized - user does not own this comment',
        );
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

  /// Fetch comments that are under review (flagged by AI).
  Future<List<Comment>> getFlaggedComments({int limit = 20}) async {
    try {
      final data = await _client
          .from(SupabaseConfig.commentsTable)
          .select('''
            *,
            profiles!comments_author_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human
            )
          ''')
          .eq('status', 'under_review')
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List<dynamic>)
          .map((json) => Comment.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('CommentRepository: Error fetching flagged comments - $e');
      return [];
    }
  }

  /// Fetch moderation case metadata for a list of comment IDs.
  Future<Map<String, Map<String, dynamic>>> getCommentModerationMetadata(
    List<String> commentIds,
  ) async {
    if (commentIds.isEmpty) return {};
    try {
      final data = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select(
            'id, comment_id, reason, source, ai_confidence, ai_model, ai_metadata, status, priority, description',
          )
          .inFilter('comment_id', commentIds);

      final result = <String, Map<String, dynamic>>{};
      for (final row in (data as List<dynamic>)) {
        final map = row as Map<String, dynamic>;
        final commentId = map['comment_id'] as String;
        result[commentId] = map;
      }
      return result;
    } catch (e) {
      debugPrint(
        'CommentRepository: Error fetching comment moderation metadata - $e',
      );
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI DETECTION FOR COMMENTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Minimum character count for AI detection.
  /// Short comments (greetings, reactions) are auto-published without AI check.
  static const int _minAiDetectionLength = 50;

  /// Run AI detection on a comment's text.
  /// Updates the comment's ai_score and status based on the result.
  /// Returns the AI probability score on success, or null on failure.
  /// Comments shorter than [_minAiDetectionLength] are auto-published.
  Future<double?> runAiDetection({
    required String commentId,
    required String authorId,
    required String body,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) return null;

    // Short comments are auto-published without AI detection.
    // AI detection APIs don't work well with very short text.
    if (trimmedBody.length < _minAiDetectionLength) {
      debugPrint(
        'CommentRepository: Skipping AI detection for short comment $commentId '
        '(${trimmedBody.length} chars < $_minAiDetectionLength)',
      );

      // Auto-publish the comment
      await _client
          .from(SupabaseConfig.commentsTable)
          .update({
            'status': 'published',
            'ai_score': 0.0,
            'ai_score_status': 'pass',
          })
          .eq('id', commentId);

      // Award ROOK for the comment (skip if commenting on own post)
      try {
        final isSelf = await _isCommentOnOwnPost(
          commentId: commentId,
          authorId: authorId,
        );
        if (!isSelf) {
          final walletRepo = WalletRepository();
          await walletRepo.earnRoo(
            userId: authorId,
            activityType: RookenActivityType.postComment,
            referenceCommentId: commentId,
          );
        }
      } catch (e) {
        debugPrint(
          'CommentRepository: Error awarding ROOK for short comment - $e',
        );
      }

      return 0.0; // Return 0 AI probability (human)
    }

    try {
      final result = await _aiDetectionService.detectText(trimmedBody);

      if (result != null) {
        // Convert API confidence to AI probability (same logic as posts)
        final bool isAiResult =
            result.result == 'AI-GENERATED' ||
            result.result == 'LIKELY AI-GENERATED';
        final double aiProbability = isAiResult
            ? result.confidence
            : 100 - result.confidence;

        // Determine new status based on AI probability (aligned with API docs)
        String newStatus;
        String scoreStatus = 'pass';
        String? authenticityNotes = result.rationale;

        // Check standalone moderation result first
        final mod = result.moderation;
        final bool isModerationFlagged = mod?.flagged ?? false;

        if (isModerationFlagged) {
          scoreStatus = 'flagged';
          // Follow recommended action
          if (mod?.recommendedAction == 'block' || mod?.recommendedAction == 'block_and_report') {
            newStatus = 'deleted';
          } else {
            newStatus = 'under_review';
          }
          authenticityNotes = 'CONTENT MODERATION: ${mod?.details ?? "Harmful content detected"}';
        } else if (aiProbability > 95) {
          newStatus = 'deleted'; // Auto-block high-confidence AI content
          scoreStatus = 'flagged';
        } else if (aiProbability > 75) {
          newStatus = 'under_review'; // Flag for review
          scoreStatus = 'flagged';
        } else if (aiProbability > 60) {
          newStatus = 'published'; // Add transparency label but publish
          scoreStatus = 'review';
          authenticityNotes =
              'HUMAN SCORE: ${(100 - aiProbability).toStringAsFixed(1)}% [REVIEW]';
        } else {
          newStatus = 'published'; // Auto-publish safe content
          scoreStatus = 'pass';
        }

        // Update comment with AI score and status
        await _client
            .from(SupabaseConfig.commentsTable)
            .update({
              'ai_score': aiProbability,
              'status': newStatus,
              'ai_score_status': scoreStatus,
              'verification_session_id': result.analysisId,
              'ai_metadata': {
                'authenticity_notes': authenticityNotes,
                'consensus_strength': result.consensusStrength,
                'rationale': result.rationale,
                'moderation': result.moderation?.toJson(),
                'safety_score': result.safetyScore,
              },
            })
            .eq('id', commentId);

        debugPrint(
          'CommentRepository: AI detection for comment $commentId - '
          'score=$aiProbability, status=$newStatus',
        );

        // Send notification to author about AI check result
        await _sendAiResultNotification(
          userId: authorId,
          commentId: commentId,
          commentStatus: newStatus,
          aiProbability: aiProbability,
        );

        // Create moderation case if flagged or review required
        if (scoreStatus == 'flagged' || scoreStatus == 'review' || isModerationFlagged) {
          await _createModerationCase(
            commentId: commentId,
            authorId: authorId,
            aiConfidence: aiProbability,
            aiModel: result.analysisId,
            aiMetadata: {
              'consensus_strength': result.consensusStrength,
              'rationale': result.rationale,
              'combined_evidence': result.combinedEvidence,
              'classification': result.result,
              'moderation': result.moderation?.toJson(),
              'safety_score': result.safetyScore,
            },
          );
        } else {
          // Comment passed AI check - award 2 ROOK to author (skip if own post)
          try {
            final isSelf = await _isCommentOnOwnPost(
              commentId: commentId,
              authorId: authorId,
            );
            if (!isSelf) {
              final walletRepo = WalletRepository();
              await walletRepo.earnRoo(
                userId: authorId,
                activityType: RookenActivityType.postComment,
                referenceCommentId: commentId,
              );
            }
          } catch (e) {
            debugPrint(
              'CommentRepository: Error awarding ROOK for comment - $e',
            );
          }
        }

        return aiProbability;
      }
 else {
        debugPrint(
          'CommentRepository: AI detection returned null for comment $commentId',
        );
        return null;
      }
    } catch (e) {
      debugPrint(
        'CommentRepository: AI detection failed for comment $commentId - $e',
      );
      return null;
    }
  }

  /// Create a moderation case for an AI-flagged comment.
  Future<void> _createModerationCase({
    required String commentId,
    required String authorId,
    required double aiConfidence,
    String? aiModel,
    Map<String, dynamic>? aiMetadata,
  }) async {
    try {
      // Check if a case already exists
      final existing = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select('id')
          .eq('comment_id', commentId)
          .maybeSingle();

      if (existing != null) {
        debugPrint(
          'CommentRepository: Moderation case already exists for comment $commentId',
        );
        return;
      }

      await _client.from(SupabaseConfig.moderationCasesTable).insert({
        'comment_id': commentId,
        'reported_user_id': authorId,
        'reason': 'ai_generated',
        'source': 'ai',
        'ai_confidence': aiConfidence,
        'ai_model': aiModel,
        'ai_metadata': aiMetadata ?? {},
        'status': 'pending',
        'priority': 'normal',
        'description':
            'Automated AI detection flagged this comment with '
            '${aiConfidence.toStringAsFixed(1)}% confidence.',
      });

      debugPrint(
        'CommentRepository: Created moderation case for comment $commentId',
      );
    } catch (e) {
      debugPrint(
        'CommentRepository: Error creating moderation case for comment $commentId - $e',
      );
    }
  }

  /// Approve or reject a flagged comment.
  Future<bool> moderateComment({
    required String commentId,
    required String action,
    String? moderatorId,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (action == 'approve') {
        updates['status'] = 'published';
      } else if (action == 'reject') {
        updates['status'] = 'deleted';
      } else {
        return false;
      }

      await _client
          .from(SupabaseConfig.commentsTable)
          .update(updates)
          .eq('id', commentId);

        // If approved, award 2 ROOK to comment author (skip if own post)
        if (action == 'approve') {
          try {
            final comment = await _client
                .from(SupabaseConfig.commentsTable)
                .select('author_id, post_id')
                .eq('id', commentId)
                .single();

            final authorId = comment['author_id'] as String;
            final postId = comment['post_id'] as String?;

            bool isSelf = false;
            if (postId != null && postId.isNotEmpty) {
              isSelf = await _isAuthorOfPost(
                authorId: authorId,
                postId: postId,
              );
            }

            if (isSelf) return true;
            final walletRepo = WalletRepository();
            await walletRepo.earnRoo(
              userId: authorId,
              activityType: RookenActivityType.postComment,
              referenceCommentId: commentId,
            );
          } catch (e) {
            debugPrint(
              'CommentRepository: Error awarding ROOK on comment approval - $e',
            );
          }
        }

      // Resolve the moderation case
      try {
        final caseUpdates = <String, dynamic>{
          'status': 'resolved',
          'decision': action == 'approve' ? 'approved' : 'rejected',
          'decided_at': DateTime.now().toIso8601String(),
        };
        if (moderatorId != null) {
          caseUpdates['assigned_admin_id'] = moderatorId;
        }
        caseUpdates['decision_notes'] =
            notes ?? 'Moderator ${action}d this comment';

        await _client
            .from(SupabaseConfig.moderationCasesTable)
            .update(caseUpdates)
            .eq('comment_id', commentId)
            .eq('status', 'pending');
      } catch (e) {
        debugPrint(
          'CommentRepository: Error resolving moderation case for comment $commentId - $e',
        );
      }

      // Submit feedback to the AI learning system
      try {
        // Look up the analysis_id from the moderation case
        final modCase = await _client
            .from(SupabaseConfig.moderationCasesTable)
            .select('ai_model')
            .eq('comment_id', commentId)
            .maybeSingle();
        final analysisId = modCase?['ai_model'] as String?;

        if (analysisId != null && analysisId.isNotEmpty) {
          final correctResult = action == 'approve'
              ? 'HUMAN-GENERATED'
              : 'AI-GENERATED';
          _aiDetectionService.submitFeedback(
            analysisId: analysisId,
            correctResult: correctResult,
            feedbackNotes: notes ?? 'Moderator $action decision on comment',
          );
        }
      } catch (e) {
        debugPrint(
          'CommentRepository: Error submitting AI feedback for comment $commentId - $e',
        );
      }

      return true;
    } catch (e) {
      debugPrint('CommentRepository: Error moderating comment $commentId - $e');
      return false;
    }
  }

  Future<bool> _isCommentOnOwnPost({
    required String commentId,
    required String authorId,
  }) async {
    try {
      final comment = await _client
          .from(SupabaseConfig.commentsTable)
          .select('post_id')
          .eq('id', commentId)
          .single();

      final postId = comment['post_id'] as String?;
      if (postId == null || postId.isEmpty) return false;

      return await _isAuthorOfPost(authorId: authorId, postId: postId);
    } catch (e) {
      debugPrint(
        'CommentRepository: Error checking self-comment for $commentId - $e',
      );
      return false;
    }
  }

  Future<bool> _isAuthorOfPost({
    required String authorId,
    required String postId,
  }) async {
    try {
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id')
          .eq('id', postId)
          .single();

      final postAuthorId = post['author_id'] as String?;
      return postAuthorId == authorId;
    } catch (e) {
      debugPrint(
        'CommentRepository: Error checking post author for $postId - $e',
      );
      return false;
    }
  }

  /// Send a notification to the comment author about AI detection result.
  Future<void> _sendAiResultNotification({
    required String userId,
    required String commentId,
    required String commentStatus,
    required double aiProbability,
  }) async {
    try {
      String title;
      String body;
      String type;

      switch (commentStatus) {
        case 'published':
          // Don't notify for published comments - too noisy
          return;
        case 'under_review':
          title = 'Comment Under Review';
          body = 'Your comment is being reviewed by our moderation team.';
          type = 'mention'; // Using 'mention' as valid DB type for system notifications
          break;
        case 'deleted':
          title = 'Comment Not Published';
          body = 'Your comment was flagged as potentially AI-generated (${aiProbability.toStringAsFixed(0)}% confidence).';
          type = 'mention';
          break;
        default:
          return; // Don't send notification for unknown status
      }

      await _notificationRepository.createNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        commentId: commentId,
      );

      debugPrint(
        'CommentRepository: Sent AI result notification to $userId for comment $commentId (status: $commentStatus)',
      );
    } catch (e) {
      debugPrint(
        'CommentRepository: Error sending AI result notification - $e',
      );
    }
  }
}
