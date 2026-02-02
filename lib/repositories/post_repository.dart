import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'media_repository.dart';
import 'tag_repository.dart';
import 'mention_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_detection_result.dart';
import '../services/ai_detection_service.dart';

/// Repository for post-related Supabase operations.
class PostRepository {
  final _client = SupabaseService().client;
  final MediaRepository _mediaRepository = MediaRepository();
  final TagRepository _tagRepository = TagRepository();
  final MentionRepository _mentionRepository = MentionRepository();
  final AiDetectionService _aiDetectionService = AiDetectionService();

  /// Fetch paginated feed of published posts.
  /// Respects privacy settings: filters posts based on author's posts_visibility setting.
  Future<List<Post>> getFeed({
    int limit = 20,
    int offset = 0,
    String? currentUserId,
  }) async {
    // Fetch more posts than needed to account for privacy filtering
    final fetchLimit = limit * 2;

    // Fetch original posts
    final postsFuture = _client
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          profiles!posts_author_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            verified_human,
            posts_visibility
          ),
          reactions!reactions_post_id_fkey (
            user_id,
            reaction_type
          ),
          comments!comments_post_id_fkey (
            id
          ),
          post_media (
            id,
            media_type,
            storage_path,
            mime_type,
            width,
            height,
            duration_seconds
          ),
          post_tags (
            tags (
              id,
              name
            )
          ),
          mentions (
            mentioned_user_id
          )
        ''')
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    // Fetch reposts
    final repostsFuture = _client
        .from(SupabaseConfig.repostsTable)
        .select('''
          *,
          reposter:profiles!reposts_user_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            verified_human
          ),
          posts!reposts_post_id_fkey (
            *,
            profiles!posts_author_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human,
              posts_visibility
            ),
            reactions!reactions_post_id_fkey (
              user_id,
              reaction_type
            ),
            comments!comments_post_id_fkey (
              id
            ),
            post_media (
              id,
              media_type,
              storage_path,
              mime_type,
              width,
              height,
              duration_seconds
            ),
            post_tags (
              tags (
                id,
                name
              )
            ),
            mentions (
              mentioned_user_id
            )
          )
        ''')
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final results = await Future.wait([postsFuture, repostsFuture]);
    final postData = results[0] as List<dynamic>;
    final repostData = results[1] as List<dynamic>;

    // Convert posts
    final posts = postData
        .map((json) => Post.fromSupabase(json, currentUserId: currentUserId))
        .toList();

    // Convert reposts
    final reposts = repostData.map((json) {
      final originalPostJson = json['posts'] as Map<String, dynamic>;
      final reposterJson = json['reposter'] as Map<String, dynamic>;

      final post = Post.fromSupabase(
        originalPostJson,
        currentUserId: currentUserId,
      );
      return post.copyWith(
        reposter: PostAuthor(
          userId: reposterJson['user_id'] as String?,
          displayName: reposterJson['display_name'] ?? '',
          username: reposterJson['username'] ?? 'unknown',
          avatar: reposterJson['avatar_url'] ?? '',
          isVerified: reposterJson['verified_human'] == 'verified',
        ),
        repostedAt: json['created_at'] as String?,
      );
    }).toList();

    // Merge and sort
    final allItems = [...posts, ...reposts];
    allItems.sort((a, b) {
      final timeA = DateTime.parse(a.repostedAt ?? a.timestamp);
      final timeB = DateTime.parse(b.repostedAt ?? b.timestamp);
      return timeB.compareTo(timeA); // Descending
    });

    // Filter based on privacy settings
    final filteredPosts = await _filterPostsByPrivacy(
      allItems,
      currentUserId: currentUserId,
    );

    // Return only the requested limit
    return filteredPosts.take(limit).toList();
  }

  /// Filter posts based on privacy settings.
  /// - 'everyone': visible to all
  /// - 'followers': visible only to followers
  /// - 'private': visible only to the author
  Future<List<Post>> _filterPostsByPrivacy(
    List<Post> posts, {
    String? currentUserId,
  }) async {
    if (currentUserId == null) {
      // Not logged in - only show 'everyone' posts
      return posts.where((post) {
        final visibility = post.author.postsVisibility ?? 'everyone';
        return visibility == 'everyone';
      }).toList();
    }

    // Get list of users that current user follows
    final followingIds = await _getFollowingIds(currentUserId);

    return posts.where((post) {
      final authorId = post.author.userId;
      final visibility = post.author.postsVisibility ?? 'everyone';

      // Author can always see their own posts
      if (authorId == currentUserId) {
        return true;
      }

      // Check visibility settings
      switch (visibility) {
        case 'everyone':
          return true;
        case 'followers':
          return followingIds.contains(authorId);
        case 'private':
          return false; // Only author can see
        default:
          return true; // Default to public if unknown setting
      }
    }).toList();
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
      debugPrint('PostRepository: Error fetching following list - $e');
      return {};
    }
  }

  /// Fetch a single post by ID with full details.
  /// Respects privacy settings: returns null if the current user is not allowed to view the post.
  Future<Post?> getPost(String postId, {String? currentUserId}) async {
    final response = await _client
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          profiles!posts_author_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            verified_human,
            posts_visibility
          ),
          reactions!reactions_post_id_fkey (
            user_id,
            reaction_type
          ),
          comments!comments_post_id_fkey (
            id
          ),
          post_media (
            id,
            media_type,
            storage_path,
            mime_type,
            width,
            height,
            duration_seconds
          ),
          post_tags (
            tags (
              id,
              name
            )
          ),
          mentions (
            mentioned_user_id
          )
        ''')
        .eq('id', postId)
        .maybeSingle();

    if (response == null) return null;

    final post = Post.fromSupabase(response, currentUserId: currentUserId);

    // Check privacy settings
    final filtered = await _filterPostsByPrivacy([
      post,
    ], currentUserId: currentUserId);

    return filtered.isNotEmpty ? filtered.first : null;
  }

  /// Fetch posts by a specific user.
  /// Respects privacy settings: filters posts based on author's posts_visibility setting.
  Future<List<Post>> getPostsByUser(
    String userId, {
    int limit = 20,
    int offset = 0,
    String? currentUserId,
  }) async {
    // Fetch more items than needed to account for privacy filtering
    final fetchLimit = limit * 2;

    // Fetch user's original posts
    dynamic postsFuture = _client
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          profiles!posts_author_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            verified_human,
            posts_visibility
          ),
          reactions!reactions_post_id_fkey (
            user_id,
            reaction_type
          ),
          comments!comments_post_id_fkey (
            id
          ),
          post_media (
            id,
            media_type,
            storage_path,
            mime_type,
            width,
            height,
            duration_seconds
          ),
          post_tags (
            tags (
              id,
              name
            )
          ),
          mentions (
            mentioned_user_id
          )
        ''')
        .eq('author_id', userId);

    // If viewing own profile, show both published and under-review posts
    if (currentUserId == userId) {
      postsFuture = postsFuture.or(
        'status.eq.published,status.eq.under_review',
      );
    } else {
      postsFuture = postsFuture.eq('status', 'published');
    }

    postsFuture = postsFuture
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    // Fetch user's reposts
    final repostsFuture = _client
        .from(SupabaseConfig.repostsTable)
        .select('''
          *,
          reposter:profiles!reposts_user_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            verified_human
          ),
          posts!reposts_post_id_fkey (
            *,
            profiles!posts_author_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human,
              posts_visibility
            ),
            reactions!reactions_post_id_fkey (
              user_id,
              reaction_type
            ),
            comments!comments_post_id_fkey (
              id
            ),
            post_media (
              id,
              media_type,
              storage_path,
              mime_type,
              width,
              height,
              duration_seconds
            ),
            post_tags (
              tags (
                id,
                name
              )
            ),
            mentions (
              mentioned_user_id
            )
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final results = await Future.wait<dynamic>([postsFuture, repostsFuture]);
    final postData = results[0] as List<dynamic>;
    final repostData = results[1] as List<dynamic>;

    // Convert posts
    final posts = postData
        .map(
          (json) => Post.fromSupabase(
            json as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();

    // Convert reposts
    final reposts = repostData.map((json) {
      final originalPostJson = json['posts'] as Map<String, dynamic>;
      final reposterJson = json['reposter'] as Map<String, dynamic>;

      final post = Post.fromSupabase(
        originalPostJson,
        currentUserId: currentUserId,
      );
      return post.copyWith(
        reposter: PostAuthor(
          userId: reposterJson['user_id'] as String?,
          displayName: reposterJson['display_name'] ?? '',
          username: reposterJson['username'] ?? 'unknown',
          avatar: reposterJson['avatar_url'] ?? '',
          isVerified: reposterJson['verified_human'] == 'verified',
        ),
        repostedAt: json['created_at'] as String?,
      );
    }).toList();

    // Merge and sort
    final allItems = [...posts, ...reposts];
    allItems.sort((a, b) {
      final timeA = DateTime.parse(a.repostedAt ?? a.timestamp);
      final timeB = DateTime.parse(b.repostedAt ?? b.timestamp);
      return timeB.compareTo(timeA); // Descending
    });

    // Filter based on privacy settings
    final filteredPosts = await _filterPostsByPrivacy(
      allItems,
      currentUserId: currentUserId,
    );

    // Return only the requested limit
    return filteredPosts.take(limit).toList();
  }

  /// Create a new post with optional media, tags, location, and mentions.
  Future<Post?> createPost({
    required String authorId,
    required String body,
    String? title,
    String bodyFormat = 'plain',
    List<File>? mediaFiles,
    List<String>? mediaTypes, // 'image' or 'video' for each media
    List<String>? tags, // Tag names (hashtags/topics)
    String? location,
    List<String>? mentionedUserIds,
  }) async {
    try {
      // Create the post first to get the postId
      final postData = <String, dynamic>{
        'author_id': authorId,
        'body': body,
        'title': title,
        'body_format': bodyFormat,
        'status': 'under_review', // Start under review for admin/AI moderation
      };
      if (location != null) postData['location'] = location;

      final response = await _client
          .from(SupabaseConfig.postsTable)
          .insert(postData)
          .select('id')
          .single();

      final postId = response['id'] as String;

      // Upload media files and create post_media records
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (var i = 0; i < mediaFiles.length; i++) {
          final mediaType = (mediaTypes != null && i < mediaTypes.length)
              ? mediaTypes[i]
              : 'image';
          final storagePath = await _mediaRepository.uploadMedia(
            file: mediaFiles[i],
            userId: authorId,
            postId: postId,
            mediaType: mediaType,
            index: i,
          );
          if (storagePath != null) {
            await _mediaRepository.createPostMedia(
              postId: postId,
              mediaType: mediaType,
              storagePath: storagePath,
            );
          }
        }
      }

      // Add tags
      if (tags != null && tags.isNotEmpty) {
        await _tagRepository.addTagsToPost(postId: postId, tagNames: tags);
      }

      // Add mentions
      if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) {
        await _mentionRepository.addMentionsToPost(
          postId: postId,
          mentionedUserIds: mentionedUserIds,
        );
      }

      // Automatically run AI detection for newly created posts
      runAiDetection(
        postId: postId,
        authorId: authorId,
        body: body,
        mediaFiles: mediaFiles,
      );

      // Small delay to ensure DB triggers/replication settle before fetching full post
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch the complete post with all relations
      return await getPost(postId, currentUserId: authorId);
    } catch (e) {
      debugPrint('PostRepository: Error creating post - $e');
      return null;
    }
  }

  /// Delete a post (soft delete by setting status to 'deleted').
  /// Validates ownership before deleting.
  Future<bool> deletePost(
    String postId, {
    required String currentUserId,
  }) async {
    try {
      // RLS enforces this at DB level, but we check here for a clear error message
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id')
          .eq('id', postId)
          .maybeSingle();

      if (post == null) {
        debugPrint('PostRepository: Post not found');
        return false;
      }

      if (post['author_id'] != currentUserId) {
        debugPrint(
          'PostRepository: Unauthorized - user does not own this post',
        );
        return false;
      }

      await _client
          .from(SupabaseConfig.postsTable)
          .update({'status': 'deleted'})
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error deleting post - $e');
      return false;
    }
  }

  /// Unpublish a post (set status to 'draft').
  /// Validates ownership before unpublishing.
  Future<bool> unpublishPost(
    String postId, {
    required String currentUserId,
  }) async {
    try {
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id')
          .eq('id', postId)
          .maybeSingle();

      if (post == null || post['author_id'] != currentUserId) {
        debugPrint('PostRepository: Unauthorized or post not found');
        return false;
      }

      await _client
          .from(SupabaseConfig.postsTable)
          .update({'status': 'draft'})
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error unpublishing post - $e');
      return false;
    }
  }

  /// Republish a draft post (set status back to 'published').
  /// Validates ownership before republishing.
  Future<bool> republishPost(
    String postId, {
    required String currentUserId,
  }) async {
    try {
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id')
          .eq('id', postId)
          .maybeSingle();

      if (post == null || post['author_id'] != currentUserId) {
        debugPrint('PostRepository: Unauthorized or post not found');
        return false;
      }

      await _client
          .from(SupabaseConfig.postsTable)
          .update({'status': 'published'})
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error republishing post - $e');
      return false;
    }
  }

  /// Fetch draft (unpublished) posts for a user.
  Future<List<Post>> getDraftsByUser(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.postsTable)
          .select('''
            *,
            profiles!posts_author_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human,
              posts_visibility
            ),
            reactions!reactions_post_id_fkey (
              user_id,
              reaction_type
            ),
            comments!comments_post_id_fkey (
              id
            ),
            post_media (
              id,
              media_type,
              storage_path,
              mime_type,
              width,
              height,
              duration_seconds
            ),
            post_tags (
              tags (
                id,
                name
              )
            ),
            mentions (
              mentioned_user_id
            )
          ''')
          .eq('author_id', userId)
          .eq('status', 'draft')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (json) => Post.fromSupabase(
              json as Map<String, dynamic>,
              currentUserId: userId,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('PostRepository: Error fetching drafts - $e');
      return [];
    }
  }

  /// Update a post's content.
  /// Validates ownership before updating.
  Future<bool> updatePost({
    required String postId,
    required String currentUserId,
    String? body,
    String? title,
    String? location,
  }) async {
    try {
      // RLS enforces this at DB level, but we check here for a clear error message
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id')
          .eq('id', postId)
          .maybeSingle();

      if (post == null || post['author_id'] != currentUserId) {
        debugPrint('PostRepository: Unauthorized or post not found');
        return false;
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (body != null) updates['body'] = body;
      if (title != null) updates['title'] = title;
      if (location != null) updates['location'] = location;

      await _client
          .from(SupabaseConfig.postsTable)
          .update(updates)
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error updating post - $e');
      return false;
    }
  }

  /// Update tip total for a post.
  Future<bool> tipPost(String postId, double newTotal) async {
    try {
      await _client
          .from(SupabaseConfig.postsTable)
          .update({'tip_total': newTotal})
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error tipping post - $e');
      return false;
    }
  }

  /// Update a post's AI score in Supabase.
  /// Writes to `ai_score` and `ai_score_status` columns.
  Future<bool> _updateAiScore({
    required String postId,
    required double confidence,
    required String scoreStatus,
    String? postStatus,
  }) async {
    try {
      final updates = <String, dynamic>{
        'ai_score': confidence,
        'ai_score_status': scoreStatus,
      };

      if (postStatus != null) {
        updates['status'] = postStatus;
      }

      await _client
          .from(SupabaseConfig.postsTable)
          .update(updates)
          .eq('id', postId);
      debugPrint(
        'PostRepository: Updated AI score - postId=$postId, score=$confidence, status=$postStatus',
      );
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error updating AI score - $e');
      return false;
    }
  }

  /// Fetch posts pending moderation.
  Future<List<Post>> getModerationQueue({int limit = 20}) async {
    try {
      final postsFuture = _client
          .from(SupabaseConfig.postsTable)
          .select('''
            *,
            profiles!posts_author_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human
            ),
            post_media (
              id,
              media_type,
              storage_path,
              mime_type
            )
          ''')
          .eq('status', 'under_review')
          .order('created_at', ascending: false)
          .limit(limit);

      final data = await postsFuture as List<dynamic>;

      return data
          .map((json) => Post.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PostRepository: Error fetching moderation queue - $e');
      return [];
    }
  }

  /// Approve or Reject a post.
  /// action: 'approve' (publish) or 'reject' (mark rejected).
  Future<bool> moderatePost({
    required String postId,
    required String action,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (action == 'approve') {
        updates['status'] = 'published';
        updates['ai_score_status'] = 'pass'; // Override AI decision
      } else if (action == 'reject') {
        updates['status'] = 'deleted';
      } else {
        return false;
      }

      await _client
          .from(SupabaseConfig.postsTable)
          .update(updates)
          .eq('id', postId);

      // Also resolve any pending moderation cases for this post
      try {
        await _client
            .from(SupabaseConfig.moderationCasesTable)
            .update({
              'status': 'resolved',
              'decision': action == 'approve' ? 'approved' : 'rejected',
              'decided_at': DateTime.now().toIso8601String(),
            })
            .eq('post_id', postId)
            .eq('status', 'pending');
      } catch (e) {
        debugPrint(
          'PostRepository: Error resolving moderation case for $postId - $e',
        );
        // We don't fail the whole operation if the mod case update fails
      }

      return true;
    } catch (e) {
      debugPrint('PostRepository: Error moderating post $postId - $e');
      return false;
    }
  }

  /// Run AI detection for a post in the background.
  /// Picks the right endpoint based on content type:
  ///   - Text only → /detect/text
  ///   - Media only → /detect/image (first file)
  ///   - Both → /detect/mixed (text + first file)
  /// Returns the confidence score on success, or null on failure.
  Future<double?> runAiDetection({
    required String postId,
    required String authorId,
    required String body,
    List<File>? mediaFiles,
  }) async {
    try {
      final hasText = body.trim().isNotEmpty;
      final hasMedia = mediaFiles != null && mediaFiles.isNotEmpty;

      AiDetectionResult? result;

      if (hasText && hasMedia) {
        result = await _aiDetectionService.detectMixed(body, mediaFiles.first);
      } else if (hasText) {
        result = await _aiDetectionService.detectText(body);
      } else if (hasMedia) {
        result = await _aiDetectionService.detectImage(mediaFiles.first);
      } else {
        return null; // Nothing to detect
      }

      if (result != null) {
        // The API's confidence represents certainty in its classification
        // label, NOT AI probability. Convert to AI probability:
        //   "AI-GENERATED" / "LIKELY AI-GENERATED"     → aiProb = confidence
        //   "HUMAN-GENERATED" / "LIKELY HUMAN-GENERATED" → aiProb = 100 - confidence
        final bool isAiResult =
            result.result == 'AI-GENERATED' ||
            result.result == 'LIKELY AI-GENERATED';
        final double aiProbability = isAiResult
            ? result.confidence
            : 100 - result.confidence;

        // Map AI probability to score status & post status
        final String scoreStatus;
        final String postStatus;

        if (aiProbability >= 75) {
          scoreStatus = 'flagged';
          postStatus = 'under_review'; // Stays under review
        } else if (aiProbability >= 50) {
          scoreStatus = 'review';
          postStatus = 'under_review'; // High enough for manual review
        } else {
          scoreStatus = 'pass';
          postStatus = 'published'; // Auto-publish if safe
        }

        await _updateAiScore(
          postId: postId,
          confidence: aiProbability,
          scoreStatus: scoreStatus,
          postStatus: postStatus,
        );

        // Automatically create a moderation case if flagged
        if (scoreStatus == 'flagged') {
          await _createModerationCase(
            postId: postId,
            authorId: authorId,
            aiConfidence: aiProbability,
            aiModel: result.analysisId,
            aiMetadata: result.modelAnalyses,
          );
        }

        return aiProbability;
      } else {
        debugPrint(
          'PostRepository: AI detection returned null for post $postId',
        );
        return null;
      }
    } catch (e) {
      debugPrint('PostRepository: AI detection failed for post $postId - $e');
      return null;
    }
  }

  /// Create a moderation case for an AI-flagged post if one doesn't exist.
  Future<void> _createModerationCase({
    required String postId,
    required String authorId,
    required double aiConfidence,
    String? aiModel,
    List<dynamic>? aiMetadata,
  }) async {
    try {
      debugPrint(
        'PostRepository: Attempting to create mod case for post $postId',
      );

      // 1. Check if a case already exists for this post
      final existing = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select('id')
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        debugPrint(
          'PostRepository: Moderation case already exists for post $postId (id: ${existing['id']})',
        );
        return;
      }

      // 2. Create the moderation case
      await _client.from(SupabaseConfig.moderationCasesTable).insert({
        'post_id': postId,
        'reported_user_id': authorId,
        'reason': 'ai_generated',
        'source': 'ai',
        'ai_confidence': aiConfidence,
        'ai_model': aiModel,
        'ai_metadata': aiMetadata ?? {},
        'status': 'pending',
        'priority': 'normal',
        'description':
            'Automated AI detection flagged this content with ${aiConfidence.toStringAsFixed(1)}% confidence.',
      });

      debugPrint(
        'PostRepository: Automated moderation case creation command sent for post $postId',
      );
    } catch (e) {
      debugPrint(
        'PostRepository: CRITICAL error creating automated moderation case - $e',
      );
      if (e is PostgrestException) {
        debugPrint(
          'PostRepository: PostgrestError: ${e.message}, hint: ${e.hint}, details: ${e.details}, code: ${e.code}',
        );
      }
    }
  }
}
