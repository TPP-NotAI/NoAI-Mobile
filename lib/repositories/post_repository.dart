import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'media_repository.dart';
import 'tag_repository.dart';
import 'mention_repository.dart';
import 'notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_detection_result.dart';
import '../services/ai_detection_service.dart';
import 'wallet_repository.dart';
import '../services/roobit_service.dart';
import '../services/activity_log_service.dart';

/// Repository for post-related Supabase operations.
class PostRepository {
  final _client = SupabaseService().client;
  final MediaRepository _mediaRepository = MediaRepository();
  final TagRepository _tagRepository = TagRepository();
  final MentionRepository _mentionRepository = MentionRepository();
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final AiDetectionService _aiDetectionService = AiDetectionService();
  final ActivityLogService _activityLogService = ActivityLogService();

  /// Temporary store of compressed video files awaiting AI analysis.
  /// Key: postId. Cleared by [runAiDetection] after use.
  final Map<String, List<File>> _pendingAiFiles = {};

  // Following IDs cache — avoids a DB round-trip on every feed page load.
  // Invalidated after 5 minutes or explicitly via [invalidateFollowingCache].
  Set<String>? _cachedFollowingIds;
  String? _cachedFollowingUserId;
  DateTime? _followingCacheTime;
  static const _followingCacheTtl = Duration(minutes: 5);

  /// Invalidate the following IDs cache (call after follow/unfollow).
  void invalidateFollowingCache() {
    _cachedFollowingIds = null;
    _cachedFollowingUserId = null;
    _followingCacheTime = null;
  }

  /// Fetch paginated feed of published posts.
  /// Respects privacy settings: filters posts based on author's posts_visibility setting.
  Future<List<Post>> getFeed({
    int limit = 20,
    int offset = 0,
    String? currentUserId,
  }) async {
    // Small buffer for privacy filtering (most public posts pass through)
    final fetchLimit = limit + 5;

    // Fetch original posts
    var postsFuture = _client.from(SupabaseConfig.postsTable).select('''
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
          roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
            amount_rc,
            status,
            metadata
          ),
          mentions (
            mentioned_user_id
          )
        ''');

    postsFuture = postsFuture.eq('status', 'published');

    final postResultsFuture = postsFuture
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
            roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
              amount_rc,
              status,
              metadata
            ),
            mentions (
              mentioned_user_id
            )
          )
        ''')
        .eq('posts.status', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final results = await Future.wait([
      postResultsFuture,
      repostsFuture,
    ], eagerError: false);
    final postData = results[0] as List<dynamic>;
    final repostData = results[1] as List<dynamic>;

    // Convert posts
    final posts = postData
        .map((json) => Post.fromSupabase(json, currentUserId: currentUserId))
        .toList();

    // Convert reposts
    final reposts = repostData
        .where((json) => json['posts'] != null && json['reposter'] != null)
        .map((json) {
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
        })
        .toList();

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

  /// Fetch feed of posts from users the current user follows.
  Future<List<Post>> getFollowingFeed({
    int limit = 20,
    int offset = 0,
    required String currentUserId,
  }) async {
    final followingIds = await _getFollowingIds(currentUserId);
    if (followingIds.isEmpty) return [];

    final fetchLimit = limit + 5;

    var query = _client.from(SupabaseConfig.postsTable).select('''
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
          roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
            amount_rc,
            status,
            metadata
          ),
          mentions (
            mentioned_user_id
          )
        ''');

    query = query.eq('status', 'published');
    query = query.inFilter('author_id', followingIds.toList());

    final postData = await query
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final posts = (postData as List<dynamic>)
        .map((json) => Post.fromSupabase(json, currentUserId: currentUserId))
        .toList();

    // Fetch reposts from following
    final repostData = await _client
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
            roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
              amount_rc,
              status,
              metadata
            ),
            mentions (
              mentioned_user_id
            )
          )
        ''')
        .inFilter('user_id', followingIds.toList())
        .eq('posts.status', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final reposts = (repostData as List<dynamic>)
        .where((json) => json['posts'] != null && json['reposter'] != null)
        .map((json) {
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
        })
        .toList();

    final allItems = [...posts, ...reposts];
    allItems.sort((a, b) {
      final timeA = DateTime.parse(a.repostedAt ?? a.timestamp);
      final timeB = DateTime.parse(b.repostedAt ?? b.timestamp);
      return timeB.compareTo(timeA);
    });

    final filtered = await _filterPostsByPrivacy(
      allItems,
      currentUserId: currentUserId,
    );
    return filtered.take(limit).toList();
  }

  /// Fetch trending posts sorted by engagement (likes + comments + reposts).
  Future<List<Post>> getTrendingFeed({
    int limit = 20,
    int offset = 0,
    String? currentUserId,
  }) async {
    final fetchLimit = limit + 5;

    final postData = await _client
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
          roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
            amount_rc,
            status,
            metadata
          ),
          mentions (
            mentioned_user_id
          )
        ''')
        .eq('status', 'published')
        .gte(
          'created_at',
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        )
        .order('likes_count', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final posts = (postData as List<dynamic>)
        .map((json) => Post.fromSupabase(json, currentUserId: currentUserId))
        .toList();

    // Sort by engagement score: likes + comments + reposts
    posts.sort((a, b) {
      final scoreA = a.likes + a.comments + a.reposts;
      final scoreB = b.likes + b.comments + b.reposts;
      return scoreB.compareTo(scoreA);
    });

    final filtered = await _filterPostsByPrivacy(
      posts,
      currentUserId: currentUserId,
    );
    return filtered.take(limit).toList();
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
  /// Result is cached for [_followingCacheTtl] to avoid repeated DB calls.
  Future<Set<String>> _getFollowingIds(String userId) async {
    final now = DateTime.now();
    if (_cachedFollowingIds != null &&
        _cachedFollowingUserId == userId &&
        _followingCacheTime != null &&
        now.difference(_followingCacheTime!) < _followingCacheTtl) {
      return _cachedFollowingIds!;
    }
    try {
      final response = await _client
          .from(SupabaseConfig.followsTable)
          .select('following_id')
          .eq('follower_id', userId);

      final ids = (response as List)
          .map((row) => row['following_id'] as String)
          .toSet();
      _cachedFollowingIds = ids;
      _cachedFollowingUserId = userId;
      _followingCacheTime = now;
      return ids;
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
          roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
            amount_rc,
            status,
            metadata
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
    // Small buffer for privacy filtering
    final fetchLimit = limit + 5;

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

    postsFuture = postsFuture.eq('status', 'published');

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
            roocoin_transactions!roocoin_transactions_reference_post_id_fkey (
              amount_rc,
              status,
              metadata
            ),
            mentions (
              mentioned_user_id
            )
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + fetchLimit - 1);

    final results = await Future.wait<dynamic>([
      postsFuture,
      repostsFuture,
    ], eagerError: false);
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
    final reposts = repostData
        .where((json) => json['posts'] != null && json['reposter'] != null)
        .map((json) {
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
        })
        .toList();

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
    bool isSensitive = false,
    String? sensitiveReason,
    String? scheduledAt,
    String? status,
    void Function(double progress)? onUploadProgress,
  }) async {
    try {
      // Create the post first to get the postId
      final postData = <String, dynamic>{
        'author_id': authorId,
        'body': body,
        'title': title,
        'body_format': bodyFormat,
        'status':
            status ??
            'under_review', // Start under review for admin/AI moderation
        'is_sensitive': isSensitive,
      };
      if (location != null) postData['location'] = location;
      if (sensitiveReason != null)
        postData['sensitive_reason'] = sensitiveReason;
      if (scheduledAt != null) postData['scheduled_at'] = scheduledAt;

      final response = await _client
          .from(SupabaseConfig.postsTable)
          .insert(postData)
          .select('id')
          .single();

      final postId = response['id'] as String;

      // Upload media files and create post_media records
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final aiFiles = <File>[];
        for (var i = 0; i < mediaFiles.length; i++) {
          final mediaType = (mediaTypes != null && i < mediaTypes.length)
              ? mediaTypes[i]
              : 'image';
          // Per-file progress: map file i's [0,1] into overall [i/n, (i+1)/n]
          final n = mediaFiles.length;
          final result = await _mediaRepository.uploadMedia(
            file: mediaFiles[i],
            userId: authorId,
            postId: postId,
            mediaType: mediaType,
            index: i,
            onProgress: onUploadProgress == null
                ? null
                : (p) => onUploadProgress((i + p) / n),
          );
          if (result.path != null) {
            await _mediaRepository.createPostMedia(
              postId: postId,
              mediaType: mediaType,
              storagePath: result.path!,
            );
          }
          // Use compressed file for AI if available, otherwise original
          aiFiles.add(result.aiFile ?? mediaFiles[i]);
        }
        // Store AI files so runAiDetection can use the smaller compressed versions
        _pendingAiFiles[postId] = aiFiles;
      }

      // Add tags
      if (tags != null && tags.isNotEmpty) {
        await _tagRepository.addTagsToPost(postId: postId, tagNames: tags);
      }

      // Add mentions
      final extractedMentions = _mentionRepository.extractMentions(body);
      List<String> extractedMentionUserIds = const [];
      if (extractedMentions.isNotEmpty) {
        extractedMentionUserIds = await _mentionRepository
            .resolveUsernamesToIds(extractedMentions);
      }

      final mergedMentionUserIds = {
        ...?mentionedUserIds,
        ...extractedMentionUserIds,
      }.toList();

      if (mergedMentionUserIds.isNotEmpty) {
        await _mentionRepository.addMentionsToPost(
          postId: postId,
          mentionedUserIds: mergedMentionUserIds,
        );
      }

      // AI detection is triggered by FeedProvider after post creation
      // to properly update the local feed state on completion.

      // Small delay to ensure DB triggers/replication settle before fetching full post
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch the complete post with all relations
      final post = await getPost(postId, currentUserId: authorId);

      unawaited(
        _activityLogService.log(
          userId: authorId,
          activityType: 'post',
          targetType: 'post',
          targetId: postId,
          description: 'Created a post',
          metadata: {
            'has_title': (title?.trim().isNotEmpty ?? false),
            'has_media': mediaFiles != null && mediaFiles.isNotEmpty,
            'media_count': mediaFiles?.length ?? 0,
            'status': status ?? 'under_review',
          },
        ),
      );

      return post;
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

      // Hard delete: remove all FK-dependent records first, then the post row.
      // Comments (and their reactions/mentions/mod cases)
      final comments = await _client
          .from(SupabaseConfig.commentsTable)
          .select('id')
          .eq('post_id', postId);
      final commentIds = (comments as List)
          .map((c) => c['id'] as String)
          .toList();
      if (commentIds.isNotEmpty) {
        // Replies under these comments
        final replies = await _client
            .from(SupabaseConfig.commentsTable)
            .select('id')
            .inFilter('parent_comment_id', commentIds);
        final replyIds = (replies as List)
            .map((r) => r['id'] as String)
            .toList();
        if (replyIds.isNotEmpty) {
          await _client.from(SupabaseConfig.reactionsTable).delete().inFilter('comment_id', replyIds);
          await _client.from(SupabaseConfig.mentionsTable).delete().inFilter('comment_id', replyIds);
          // Clear user_reports referencing mod cases before deleting mod cases
          final replyModCases = await _client.from(SupabaseConfig.moderationCasesTable).select('id').inFilter('comment_id', replyIds) as List<dynamic>;
          final replyModCaseIds = replyModCases.map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
          if (replyModCaseIds.isNotEmpty) {
            await _client.from(SupabaseConfig.userReportsTable).delete().inFilter('moderation_case_id', replyModCaseIds);
          }
          await _client.from(SupabaseConfig.moderationCasesTable).delete().inFilter('comment_id', replyIds);
          await _client.from(SupabaseConfig.userReportsTable).delete().inFilter('comment_id', replyIds);
          await _client.from(SupabaseConfig.commentsTable).delete().inFilter('parent_comment_id', commentIds);
        }
        await _client.from(SupabaseConfig.reactionsTable).delete().inFilter('comment_id', commentIds);
        await _client.from(SupabaseConfig.mentionsTable).delete().inFilter('comment_id', commentIds);
        // Clear user_reports referencing mod cases before deleting mod cases
        final commentModCases = await _client.from(SupabaseConfig.moderationCasesTable).select('id').inFilter('comment_id', commentIds) as List<dynamic>;
        final commentModCaseIds = commentModCases.map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
        if (commentModCaseIds.isNotEmpty) {
          await _client.from(SupabaseConfig.userReportsTable).delete().inFilter('moderation_case_id', commentModCaseIds);
        }
        await _client.from(SupabaseConfig.moderationCasesTable).delete().inFilter('comment_id', commentIds);
        await _client.from(SupabaseConfig.userReportsTable).delete().inFilter('comment_id', commentIds);
        await _client.from(SupabaseConfig.commentsTable).delete().eq('post_id', postId);
      }
      // Other post-level dependents
      await _client.from(SupabaseConfig.reactionsTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.mentionsTable).delete().eq('post_id', postId);
      // Clear user_reports referencing post-level mod cases before deleting mod cases
      final postModCases = await _client.from(SupabaseConfig.moderationCasesTable).select('id').eq('post_id', postId) as List<dynamic>;
      final postModCaseIds = postModCases.map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
      if (postModCaseIds.isNotEmpty) {
        await _client.from(SupabaseConfig.userReportsTable).delete().inFilter('moderation_case_id', postModCaseIds);
      }
      await _client.from(SupabaseConfig.moderationCasesTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.userReportsTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.bookmarksTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.repostsTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.notificationsTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.roocoinTransactionsTable).delete().eq('reference_post_id', postId);
      await _client.from('post_boosts').delete().eq('post_id', postId);
      await _client.from('post_views').delete().eq('post_id', postId);
      await _client.from('polls').delete().eq('post_id', postId);
      await _client.from('collectibles').delete().eq('post_id', postId);
      await _client.from('circle_posts').delete().eq('post_id', postId);
      await _client.from('challenge_entries').delete().eq('post_id', postId);
      await _client.from('subscriber_only_posts').delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.postTagsTable).delete().eq('post_id', postId);
      await _client.from(SupabaseConfig.postMediaTable).delete().eq('post_id', postId);
      // Finally hard-delete the post row
      await _client.from(SupabaseConfig.postsTable).delete().eq('id', postId);
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
          .select('author_id, title, body')
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

      await _notifyAuthorPostPublished(
        userId: currentUserId,
        postId: postId,
        title: post['title'] as String?,
        body: post['body'] as String?,
      );
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error republishing post - $e');
      return false;
    }
  }

  /// Publish a post that was held for ad payment (stored as `draft` in DB for
  /// enum compatibility) after the user pays the advertising fee.
  /// the advertising fee. Also broadcasts the sponsored-post notification.
  Future<bool> publishPendingAdPost(
    String postId, {
    required String currentUserId,
  }) async {
    try {
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id, status, ai_metadata, authenticity_notes')
          .eq('id', postId)
          .maybeSingle();

      if (post == null || post['author_id'] != currentUserId) {
        debugPrint('PostRepository: Unauthorized or post not found');
        return false;
      }

      final status = post['status'] as String?;
      final existingNotes = post['authenticity_notes'] as String?;
      final aiMetadata = post['ai_metadata'];
      final bool isAwaitingAdPayment =
          status == 'draft' &&
          (((existingNotes ?? '').toLowerCase().contains(
                'awaiting ad fee payment',
              )) ||
              (aiMetadata is Map &&
                  aiMetadata['advertisement'] is Map &&
                  ((aiMetadata['advertisement'] as Map)['requires_payment'] ==
                      true)));

      if (!isAwaitingAdPayment) {
        debugPrint(
          'PostRepository: Post $postId is not awaiting ad payment '
          '(status=${post["status"]})',
        );
        return false;
      }

      String? adType;
      if (aiMetadata is Map<String, dynamic>) {
        final ad = aiMetadata['advertisement'];
        if (ad is Map<String, dynamic>) {
          adType = ad['type'] as String?;
        }
      } else if (aiMetadata is Map) {
        final ad = aiMetadata['advertisement'];
        if (ad is Map) {
          final raw = ad['type'];
          if (raw is String) adType = raw;
        }
      }

      final nextNotes = (existingNotes == null || existingNotes.isEmpty)
          ? 'ADVERTISEMENT: ad fee paid'
          : existingNotes.contains('ad fee paid')
          ? existingNotes
          : '$existingNotes | ad fee paid';

      await _client
          .from(SupabaseConfig.postsTable)
          .update({
            'status': 'published',
            'is_advertisement': true,
            'authenticity_notes': nextNotes,
            'published_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', postId);

      await _notifyAuthorPostPublished(
        userId: currentUserId,
        postId: postId,
        title: null,
        body: null,
      );

      // Mark the matching advertisements row as paid.
      try {
        await _client
            .from('advertisements')
            .update({
              'status': 'paid',
              'paid_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('content_id', postId)
            .eq('content_type', 'post')
            .eq('status', 'pending_payment');
      } catch (e) {
        debugPrint('PostRepository: Failed to mark advertisement as paid - $e');
      }

      await _broadcastSponsoredPostNotification(
        postId: postId,
        authorId: currentUserId,
        adType: adType,
      );

      return true;
    } catch (e) {
      debugPrint('PostRepository: Error publishing pending ad post - $e');
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

  /// Fetch all advertisement posts for a user.
  /// Returns both published (paid) and draft (pending payment) posts
  /// that were detected as advertisements.
  Future<List<Post>> getAdsByUser(String userId) async {
    try {
      const select = '''
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
      ''';

      // Fetch published ads (paid) and draft ads (pending payment) in parallel.
      // Uses is_advertisement flag (set by AI detection) as primary filter,
      // with authenticity_notes fallback for backwards compatibility.
      final results = await Future.wait([
        _client
            .from(SupabaseConfig.postsTable)
            .select(select)
            .eq('author_id', userId)
            .eq('status', 'published')
            .or(
              'is_advertisement.eq.true,authenticity_notes.ilike.%advertisement%',
            )
            .order('created_at', ascending: false),
        _client
            .from(SupabaseConfig.postsTable)
            .select(select)
            .eq('author_id', userId)
            .eq('status', 'draft')
            .or(
              'is_advertisement.eq.true,authenticity_notes.ilike.%awaiting ad fee payment%',
            )
            .order('created_at', ascending: false),
      ]);

      final published = (results[0] as List<dynamic>)
          .map(
            (j) => Post.fromSupabase(
              j as Map<String, dynamic>,
              currentUserId: userId,
            ),
          )
          .toList();

      final pending = (results[1] as List<dynamic>)
          .map(
            (j) => Post.fromSupabase(
              j as Map<String, dynamic>,
              currentUserId: userId,
            ),
          )
          .toList();

      // Also include drafts with requires_payment flag but no notes yet
      // (edge case: notes may not have been set)
      final pendingIds = pending.map((p) => p.id).toSet();
      final allDraftsResult = await _client
          .from(SupabaseConfig.postsTable)
          .select(select)
          .eq('author_id', userId)
          .eq('status', 'draft')
          .order('created_at', ascending: false);

      for (final j in allDraftsResult as List<dynamic>) {
        final post = Post.fromSupabase(
          j as Map<String, dynamic>,
          currentUserId: userId,
        );
        if (pendingIds.contains(post.id)) continue;
        final ad = post.aiMetadata?['advertisement'];
        if (ad is Map && ad['requires_payment'] == true) {
          pending.add(post);
          pendingIds.add(post.id);
        }
      }

      return [...published, ...pending];
    } catch (e) {
      debugPrint('PostRepository: Error fetching ads - $e');
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
    bool? isSensitive,
    String? sensitiveReason,
    String? visibility,
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
      if (isSensitive != null) updates['is_sensitive'] = isSensitive;
      if (sensitiveReason != null) {
        updates['sensitive_reason'] = sensitiveReason;
      }
      if (visibility != null) updates['visibility'] = visibility;

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

  /// Count posts that are published AND human-verified (ai_score_status = 'pass').
  /// Used for the "Approved Posts" statistic on the profile screen.
  Future<int> countApprovedPosts(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.postsTable)
          .select('id')
          .eq('author_id', userId)
          .eq('status', 'published')
          .eq('ai_score_status', 'pass')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('PostRepository: Error counting approved posts - $e');
      return 0;
    }
  }

  /// Sum total likes across all posts by a user.
  Future<int> getTotalLikes(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.postsTable)
          .select('likes_count')
          .eq('author_id', userId);
      int total = 0;
      for (final row in (response as List)) {
        total += (row['likes_count'] as int? ?? 0);
      }
      return total;
    } catch (e) {
      debugPrint('PostRepository: Error getting total likes - $e');
      return 0;
    }
  }

  /// Sum total comments across all posts by a user.
  Future<int> getTotalComments(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.postsTable)
          .select('comments_count')
          .eq('author_id', userId);
      int total = 0;
      for (final row in (response as List)) {
        total += (row['comments_count'] as int? ?? 0);
      }
      return total;
    } catch (e) {
      debugPrint('PostRepository: Error getting total comments - $e');
      return 0;
    }
  }

  /// Increment the tip total for a post via RPC (bypasses RLS).
  Future<bool> tipPost(String postId, double amount) async {
    try {
      await _client.rpc(
        'increment_post_tips',
        params: {'p_post_id': postId, 'p_amount': amount},
      );
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
    String? analysisId,
    String? verificationMethod,
    String? authenticityNotes,
    Map<String, dynamic>? aiMetadata,
  }) async {
    try {
      final updates = <String, dynamic>{
        'ai_score': confidence,
        'ai_score_status': scoreStatus,
      };

      if (postStatus != null) {
        updates['status'] = postStatus;
      }
      if (analysisId != null) {
        updates['verification_session_id'] = analysisId;
      }
      if (verificationMethod != null) {
        updates['verification_method'] = verificationMethod;
      }
      if (authenticityNotes != null) {
        updates['authenticity_notes'] = authenticityNotes;
      }
      if (aiMetadata != null) {
        updates['ai_metadata'] = aiMetadata;
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

  /// Fetch AI-flagged posts belonging to a specific user.
  /// Only returns posts where the AI explicitly flagged or put them under review
  /// (ai_score_status = 'flagged' or 'review'), not posts under review for other reasons.
  Future<List<Post>> getUserFlaggedPosts(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final modCases =
          await _client
                  .from(SupabaseConfig.moderationCasesTable)
                  .select('post_id, created_at')
                  .eq('reported_user_id', userId)
                  .eq('source', 'ai')
                  .order('created_at', ascending: false)
              as List<dynamic>;

      final seenPostIds = <String>{};
      final moderatedPostIds = <String>[];
      for (final row in modCases) {
        final postId = (row as Map<String, dynamic>)['post_id'] as String?;
        if (postId == null) continue;
        if (seenPostIds.add(postId)) {
          moderatedPostIds.add(postId);
        }
        if (moderatedPostIds.length >= limit) break;
      }

      final postById = <String, Post>{};
      if (moderatedPostIds.isNotEmpty) {
        final data =
            await _client
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
                    .inFilter('id', moderatedPostIds)
                as List<dynamic>;

        for (final json in data) {
          final post = Post.fromSupabase(json as Map<String, dynamic>);
          postById[post.id] = post;
        }
      }

      // Preserve prior behavior for ad-fee-held drafts (these may not have moderation cases).
      final adDraftRows =
          await _client
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
                  .eq('author_id', userId)
                  .eq('status', 'draft')
                  .order('created_at', ascending: false)
                  .limit(limit)
              as List<dynamic>;

      for (final json in adDraftRows) {
        final post = Post.fromSupabase(json as Map<String, dynamic>);
        if (postById.containsKey(post.id)) continue;
        if (post.status == 'draft' &&
            (post.authenticityNotes ?? '').toLowerCase().contains(
              'awaiting ad fee payment',
            )) {
          postById[post.id] = post;
        }
      }

      final posts = <Post>[
        for (final id in moderatedPostIds)
          if (postById.containsKey(id)) postById[id]!,
        ...postById.values.where((p) => !moderatedPostIds.contains(p.id)),
      ];

      return posts
          .where(
            (post) =>
                post.aiScoreStatus == 'flagged' ||
                post.aiScoreStatus == 'review' ||
                (post.status == 'draft' &&
                    (post.authenticityNotes ?? '').toLowerCase().contains(
                      'awaiting ad fee payment',
                    )),
          )
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('PostRepository: Error fetching user flagged posts - $e');
      return [];
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

  /// Fetch moderation case metadata for a list of post IDs.
  /// Returns a map of postId → moderation case data (including ai_metadata).
  Future<Map<String, Map<String, dynamic>>> getModerationMetadata(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};
    try {
      final data = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select(
            'id, post_id, reason, source, ai_confidence, ai_model, ai_metadata, status, priority, description',
          )
          .inFilter('post_id', postIds);

      final result = <String, Map<String, dynamic>>{};
      for (final row in (data as List<dynamic>)) {
        final map = row as Map<String, dynamic>;
        final postId = map['post_id'] as String;
        result[postId] = map;
      }
      return result;
    } catch (e) {
      debugPrint('PostRepository: Error fetching moderation metadata - $e');
      return {};
    }
  }

  /// Approve or Reject a post.
  /// action: 'approve' (publish) or 'reject' (mark rejected).
  /// [moderatorId] is the user_id of the moderator making the decision.
  /// [notes] optional explanation for the decision.
  Future<bool> moderatePost({
    required String postId,
    required String action,
    String? moderatorId,
    String? notes,
  }) async {
    try {
      // 1. Fetch post details first to get author_id for notification
      final postData = await _client
          .from(SupabaseConfig.postsTable)
          .select('author_id, title, body')
          .eq('id', postId)
          .maybeSingle();

      if (postData == null) {
        debugPrint('PostRepository: Post $postId not found for moderation');
        return false;
      }

      final String authorId = postData['author_id'] as String;
      final String? postTitle = postData['title'] as String?;
      final String postBody = postData['body'] as String? ?? '';
      final String displayTitle =
          postTitle ??
          (postBody.length > 30 ? '${postBody.substring(0, 30)}...' : postBody);

      final updates = <String, dynamic>{};
      if (action == 'approve') {
        updates['status'] = 'published';
        updates['ai_score_status'] = 'pass'; // Override AI decision
        updates['human_certified'] =
            true; // Moderator verified as human content
      } else if (action == 'reject') {
        updates['status'] = 'deleted';
      } else {
        return false;
      }

      await _client
          .from(SupabaseConfig.postsTable)
          .update(updates)
          .eq('id', postId);

      // 2. Send Notification to Author
      try {
        if (action == 'approve') {
          await _notificationRepository.createNotification(
            userId: authorId,
            type: 'post_published',
            title: 'Post Approved',
            body:
                'Your post "$displayTitle" has been approved and is now live!',
            postId: postId,
            actorId: moderatorId, // The moderator who approved it
          );
        } else if (action == 'reject') {
          await _notificationRepository.createNotification(
            userId: authorId,
            type: 'post_flagged',
            title: 'Post Rejected',
            body: notes != null && notes.isNotEmpty
                ? 'Your post "$displayTitle" was rejected. Reason: $notes'
                : 'Your post "$displayTitle" was rejected.',
            postId: postId,
            actorId: moderatorId,
          );
        }
      } catch (e) {
        debugPrint(
          'PostRepository: Error sending moderation notification - $e',
        );
        // Continue execution, don't fail the moderation action
      }

      // If approved, award daily post ROO to the author (0.01 ROO, once per day)
      if (action == 'approve') {
        try {
          final walletRepo = WalletRepository();
          await _awardDailyPostRoo(walletRepo, authorId, postId);
        } catch (e) {
          debugPrint(
            'PostRepository: Error awarding ROO on moderation approval - $e',
          );
        }
      }

      // Also resolve any pending moderation cases for this post
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
            notes ?? 'Moderator ${action}d this post';

        await _client
            .from(SupabaseConfig.moderationCasesTable)
            .update(caseUpdates)
            .eq('post_id', postId)
            .eq('status', 'pending');
      } catch (e) {
        debugPrint(
          'PostRepository: Error resolving moderation case for $postId - $e',
        );
      }

      // Submit feedback to the AI learning system so it can improve.
      // Fetch the analysis_id stored on the post during detection.
      try {
        final postDataIdx = await _client
            .from(SupabaseConfig.postsTable)
            .select('verification_session_id')
            .eq('id', postId)
            .maybeSingle();
        final analysisId = postDataIdx?['verification_session_id'] as String?;
        if (analysisId != null && analysisId.isNotEmpty) {
          // approve = the AI was wrong (content is human), reject = AI was right
          final correctResult = action == 'approve'
              ? 'HUMAN-GENERATED'
              : 'AI-GENERATED';
          _aiDetectionService.submitFeedback(
            analysisId: analysisId,
            correctResult: correctResult,
            feedbackNotes: notes ?? 'Moderator $action decision',
          );
        }
      } catch (e) {
        debugPrint('PostRepository: Error submitting AI feedback - $e');
      }

      return true;
    } catch (e) {
      debugPrint('PostRepository: Error moderating post $postId - $e');
      return false;
    }
  }

  /// Run AI detection for a post in the background using the combined
  /// /detect/full endpoint (AI + Moderation + Advertisement in one call).
  ///
  /// When advertisement is detected with [action == 'require_payment'], the
  /// post is held as `draft` (DB enum-compatible ad-payment hold) and
  /// [onAdFeeRequired] is called with
  /// the confidence percentage so the caller can prompt the user to pay.
  ///
  /// Returns the AI confidence score on success, or null on failure.
  Future<double?> runAiDetection({
    required String postId,
    required String authorId,
    required String body,
    List<File>? mediaFiles,
    Future<bool> Function(double adConfidence, String? adType, List<String> evidence, String? rationale)? onAdFeeRequired,
  }) async {
    // Prefer compressed files stored during upload (smaller = faster AI check).
    // Fall back to the original files passed by the caller.
    final pendingFiles = _pendingAiFiles.remove(postId);
    final effectiveMediaFiles = pendingFiles ?? mediaFiles;

    try {
      final trimmedBody = body.trim();
      final hasText = trimmedBody.isNotEmpty;
      final hasMedia =
          effectiveMediaFiles != null && effectiveMediaFiles.isNotEmpty;
      final detectionModels = hasMedia ? 'gpt-4.1' : 'gpt-5.2,o3';

      if (!hasText && !hasMedia) {
        return null;
      }
      debugPrint(
        'PostRepository: Running AI detection with models=$detectionModels '
        '(hasText=$hasText, hasMedia=$hasMedia, '
        'usingCompressed=${pendingFiles != null})',
      );

      // Check every attached media item. If any item is AI, block the full post.
      final List<AiDetectionResult> detectionResults = [];
      if (hasMedia) {
        final files = effectiveMediaFiles;
        for (int i = 0; i < files.length; i++) {
          final result = await _aiDetectionService.detectFull(
            content: hasText && i == 0 ? trimmedBody : null,
            file: files[i],
            models: detectionModels,
          );
          if (result != null) {
            detectionResults.add(result);
          }
        }
      } else {
        final result = await _aiDetectionService.detectFull(
          content: hasText ? trimmedBody : null,
          file: null,
          models: detectionModels,
        );
        if (result != null) {
          detectionResults.add(result);
        }
      }

      if (detectionResults.isNotEmpty) {
        final aiDetectedResults = detectionResults.where((r) {
          final normalized = r.result.trim().toUpperCase();
          return normalized == 'AI-GENERATED' ||
              normalized == 'LIKELY AI-GENERATED';
        }).toList();
        final hasAnyAiDetected = aiDetectedResults.isNotEmpty;
        final representativeResult = hasAnyAiDetected
            ? aiDetectedResults.reduce(
                (a, b) => a.confidence >= b.confidence ? a : b,
              )
            : detectionResults.reduce(
                (a, b) => a.confidence >= b.confidence ? a : b,
              );

        // Result label is normalized to UPPER CASE in fromJson.
        // Confidence is label-specific per NOAI docs.
        final String normalizedResult = representativeResult.result
            .trim()
            .toUpperCase();
        final bool isAiResult =
            normalizedResult == 'AI-GENERATED' ||
            normalizedResult == 'LIKELY AI-GENERATED';
        final double labelConfidence = representativeResult.confidence.clamp(
          0,
          100,
        );
        // Keep an AI-risk score for DB/notifications compatibility.
        final double aiProbability = hasAnyAiDetected
            ? aiDetectedResults
                  .map((r) => r.confidence.clamp(0, 100))
                  .reduce((a, b) => a >= b ? a : b)
                  .toDouble()
            : (isAiResult ? labelConfidence : 100 - labelConfidence);

        debugPrint(
          'PostRepository: AI detection outcome: label=${representativeResult.result}, '
          'labelConfidence=$labelConfidence% -> aiProbability=$aiProbability% '
          '(items=${detectionResults.length}, aiDetected=${aiDetectedResults.length})',
        );

        // Map AI probability to score status & post status.
        String scoreStatus;
        String postStatus;
        String? authenticityNotes = representativeResult.rationale;

        // Check moderation across all analyzed items.
        final moderationFlaggedResults = detectionResults.where(
          (r) => r.moderation?.flagged ?? false,
        );
        final bool isModerationFlagged = moderationFlaggedResults.isNotEmpty;
        final modSource = isModerationFlagged
            ? moderationFlaggedResults.first
            : representativeResult;
        final mod = modSource.moderation;
        final bool hasModerationHardBlock = detectionResults.any((r) {
          final action = r.moderation?.recommendedAction;
          return action == 'block' || action == 'block_and_report';
        });

        if (isModerationFlagged) {
          scoreStatus = 'flagged';
          if (hasModerationHardBlock) {
            postStatus = 'deleted';
          } else {
            postStatus = 'under_review';
          }
          authenticityNotes =
              'CONTENT MODERATION: ${mod?.details ?? "Harmful content detected"}';
        } else if (hasAnyAiDetected) {
          scoreStatus = 'flagged';
          postStatus = 'deleted';
          authenticityNotes =
              'AI CONTENT DETECTED IN ATTACHED MEDIA (${aiDetectedResults.length}/${detectionResults.length})';
        } else if (isAiResult && labelConfidence >= 95) {
          scoreStatus = 'flagged';
          postStatus = 'deleted';
        } else if (isAiResult && labelConfidence >= 75) {
          scoreStatus = 'flagged';
          postStatus = 'under_review';
        } else if (isAiResult && labelConfidence >= 60) {
          scoreStatus = 'review';
          postStatus = 'published';
          authenticityNotes =
              'POTENTIAL AI CONTENT: ${labelConfidence.toStringAsFixed(1)}% [REVIEW]';
        } else {
          scoreStatus = 'pass';
          postStatus = 'published';
        }

        // Advertisement checks apply only when content is publishable.
        final adCarrier = detectionResults.firstWhere(
          (r) =>
              (r.advertisement?.requiresPayment ?? false) ||
              r.policyRequiresPayment ||
              r.policyAction == 'require_payment' ||
              (r.advertisement?.flaggedForReview ?? false) ||
              r.policyAction == 'flag_for_review',
          orElse: () => representativeResult,
        );
        final ad = adCarrier.advertisement;
        final requiresAdPayment = detectionResults.any(
          (r) =>
              (r.advertisement?.requiresPayment ?? false) ||
              r.policyRequiresPayment ||
              r.policyAction == 'require_payment',
        );
        final adFlaggedForReview = detectionResults.any(
          (r) =>
              (r.advertisement?.flaggedForReview ?? false) ||
              r.policyAction == 'flag_for_review',
        );
        if (postStatus == 'published' && requiresAdPayment) {
          debugPrint(
            'PostRepository: Advertisement detected - confidence='
            '${ad?.confidence ?? 0.0}%, type=${ad?.type ?? "advertisement"}, '
            'action=${ad?.action ?? adCarrier.policyAction}',
          );

          await _client
              .from(SupabaseConfig.postsTable)
              .update({'status': 'draft', 'is_advertisement': true})
              .eq('id', postId);

          final adConfidence = ad?.confidence ?? 0.0;
          final adType = ad?.type ?? 'advertisement';

          String? advertisementId;
          try {
            final adRow = await _client
                .from('advertisements')
                .insert({
                  'user_id': authorId,
                  'content_type': 'post',
                  'content_id': postId,
                  'status': 'pending_payment',
                  'amount_paid': 0,
                  'detection_confidence': adConfidence,
                  'detection_type': adType,
                  'detection_evidence': ad?.toJson() != null
                      ? [ad!.toJson()]
                      : [],
                })
                .select('id')
                .single();
            advertisementId = adRow['id'] as String?;
          } catch (e) {
            debugPrint(
              'PostRepository: Failed to insert advertisements row - $e',
            );
          }

          bool feePaid = false;
          if (onAdFeeRequired != null) {
            feePaid = await onAdFeeRequired(
              adConfidence,
              adType,
              ad?.evidence ?? [],
              ad?.rationale,
            );
          }

          if (feePaid) {
            postStatus = 'published';
            authenticityNotes =
                'ADVERTISEMENT: ${adConfidence.toStringAsFixed(1)}% confidence '
                '($adType) - ad fee paid';
            if (advertisementId != null) {
              try {
                await _client
                    .from('advertisements')
                    .update({
                      'status': 'paid',
                      'paid_at': DateTime.now().toUtc().toIso8601String(),
                    })
                    .eq('id', advertisementId);
              } catch (e) {
                debugPrint(
                  'PostRepository: Failed to update advertisements row to paid - $e',
                );
              }
            }
            await _broadcastSponsoredPostNotification(
              postId: postId,
              authorId: authorId,
              adType: adType,
            );
          } else {
            postStatus = 'draft';
            authenticityNotes =
                'ADVERTISEMENT: ${adConfidence.toStringAsFixed(1)}% confidence '
                '($adType) - awaiting ad fee payment';
          }
        } else if (postStatus == 'published' && adFlaggedForReview) {
          final adConfidence = ad?.confidence ?? 0.0;
          authenticityNotes =
              (authenticityNotes != null ? '$authenticityNotes | ' : '') +
              'POSSIBLE ADVERTISEMENT: ${adConfidence.toStringAsFixed(1)}% confidence';
        }

        if (postStatus == 'published') {
          final bool shouldAutoLabelSensitive =
              isModerationFlagged &&
              (mod?.categories['sexual'] == true ||
                  mod?.categories['violence'] == true);

          if (shouldAutoLabelSensitive) {
            await updatePost(
              postId: postId,
              currentUserId: authorId,
              isSensitive: true,
              sensitiveReason:
                  'AI Auto-detected: ${mod?.details ?? "Potentially sensitive content"}',
            );
          }

          try {
            final walletRepo = WalletRepository();
            await _awardDailyPostRoo(walletRepo, authorId, postId);
          } catch (e) {
            debugPrint(
              'PostRepository: Error awarding ROO on auto-publish - $e',
            );
          }
        }

        await _updateAiScore(
          postId: postId,
          confidence: aiProbability,
          scoreStatus: scoreStatus,
          postStatus: postStatus,
          analysisId: representativeResult.analysisId,
          verificationMethod: representativeResult.contentType,
          authenticityNotes: authenticityNotes,
          aiMetadata: {
            'consensus_strength': representativeResult.consensusStrength,
            'rationale': representativeResult.rationale,
            'combined_evidence': representativeResult.combinedEvidence,
            'classification': representativeResult.result,
            'safety_score': representativeResult.safetyScore,
            'metadata_signals': representativeResult.metadataAnalysis?.signals,
            'metadata_adjustment':
                representativeResult.metadataAnalysis?.adjustment,
            'model_results': representativeResult.modelResults
                ?.map((e) => e.toJson())
                .toList(),
            'analyzed_media_count': detectionResults.length,
            'ai_detected_media_count': aiDetectedResults.length,
            if (representativeResult.advertisement != null)
              'advertisement': representativeResult.advertisement!.toJson(),
          },
        );

        await _sendAiResultNotification(
          userId: authorId,
          postId: postId,
          postStatus: postStatus,
          aiProbability: aiProbability,
          isModerationBlock: isModerationFlagged && hasModerationHardBlock,
          moderationDetails: mod?.details,
        );

        if (scoreStatus == 'flagged' ||
            scoreStatus == 'review' ||
            isModerationFlagged) {
          await _createModerationCase(
            postId: postId,
            authorId: authorId,
            aiConfidence: aiProbability,
            aiModel: representativeResult.analysisId,
            aiMetadata: {
              'model_results': representativeResult.modelResults
                  ?.map((e) => e.toJson())
                  .toList(),
              'consensus_strength': representativeResult.consensusStrength,
              'rationale': representativeResult.rationale,
              'combined_evidence': representativeResult.combinedEvidence,
              'classification': representativeResult.result,
              'moderation': representativeResult.moderation?.toJson(),
              'safety_score': representativeResult.safetyScore,
              'analyzed_media_count': detectionResults.length,
              'ai_detected_media_count': aiDetectedResults.length,
            },
          );
        }

        return aiProbability;
      } else {
        debugPrint(
          'PostRepository: AI detection returned null for post $postId',
        );
        return null;
      }
    } on TimeoutException {
      debugPrint(
        'PostRepository: AI detection timed out for post $postId — auto-publishing as pass',
      );
      await _updateAiScore(
        postId: postId,
        confidence: 0.0,
        scoreStatus: 'pass',
        postStatus: 'published',
        authenticityNotes: 'AI detection timed out — auto-approved',
      );
      return 0.0;
    } catch (e) {
      debugPrint('PostRepository: AI detection failed for post $postId - $e');
      return null;
    } finally {
      // Delete any compressed temp files that were used for AI analysis.
      // These differ from the original mediaFiles — originals are never deleted.
      if (pendingFiles != null) {
        final originalPaths = mediaFiles?.map((f) => f.path).toSet() ?? {};
        for (final f in pendingFiles) {
          if (!originalPaths.contains(f.path)) {
            try { await f.delete(); } catch (_) {}
          }
        }
      }
    }
  }

  Future<void> _broadcastSponsoredPostNotification({
    required String postId,
    required String authorId,
    String? adType,
  }) async {
    try {
      final adLabel = (adType == null || adType.trim().isEmpty)
          ? 'sponsored content'
          : adType.replaceAll('_', ' ');
      const int pageSize = 500;
      int offset = 0;

      while (true) {
        final rows = await _client
            .from(SupabaseConfig.profilesTable)
            .select('user_id')
            .neq('user_id', authorId)
            .range(offset, offset + pageSize - 1);

        final users = (rows as List)
            .map((r) => r['user_id'] as String?)
            .whereType<String>()
            .toList();
        if (users.isEmpty) break;

        final payload = users
            .map(
              (uid) => {
                'user_id': uid,
                'type': 'mention',
                'title': 'Sponsored Post',
                'body': 'A new sponsored post is live ($adLabel).',
                'actor_id': authorId,
                'post_id': postId,
                'is_read': false,
              },
            )
            .toList();

        await _client.from(SupabaseConfig.notificationsTable).insert(payload);

        // Record each notified user in advertisement_recipients.
        final recipientPayload = users
            .map(
              (uid) => {
                'content_type': 'post',
                'content_id': postId,
                'author_id': authorId,
                'user_id': uid,
                'match_score': 0,
                'selection_reason': 'sponsored_broadcast',
              },
            )
            .toList();
        try {
          await _client
              .from('advertisement_recipients')
              .insert(recipientPayload);
        } catch (e) {
          debugPrint(
            'PostRepository: Failed to insert advertisement_recipients - $e',
          );
        }

        if (users.length < pageSize) break;
        offset += pageSize;
      }
    } catch (e) {
      debugPrint(
        'PostRepository: Failed to broadcast sponsored post notification - $e',
      );
    }
  }

  /// Create a moderation case for an AI-flagged post if one doesn't exist.
  Future<void> _createModerationCase({
    required String postId,
    required String authorId,
    required double aiConfidence,
    String? aiModel,
    Map<String, dynamic>? aiMetadata,
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

  /// Send a notification to the post author about AI detection result.
  Future<void> _sendAiResultNotification({
    required String userId,
    required String postId,
    required String postStatus,
    required double aiProbability,
    bool isModerationBlock = false,
    String? moderationDetails,
  }) async {
    try {
      String title;
      String body;
      String type;

      switch (postStatus) {
        case 'published':
          title = 'Post Published';
          body = 'Your post passed verification and is now live!';
          type = 'post_published';
          break;
        case 'under_review':
          title = 'Post Under Review';
          body = isModerationBlock
              ? 'Your post is under review for content policy reasons.'
              : 'Your post is being checked for AI. You\'ll be notified soon.';
          type = 'post_review';
          break;
        case 'deleted':
          title = 'Post Not Published';
          body = isModerationBlock
              ? 'Your post was removed for violating content policies. ${moderationDetails != null ? "Reason: $moderationDetails" : ""}'
              : 'Your post was flagged as potentially AI-generated (${aiProbability.toStringAsFixed(0)}% confidence), and was not published.';
          type = 'post_flagged';
          break;
        default:
          return; // Don't send notification for unknown status
      }

      final created = await _notificationRepository.createNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        postId: postId,
      );

      if (created) {
        debugPrint(
          'PostRepository: Sent AI result notification to $userId for post $postId (status: $postStatus)',
        );
      } else {
        debugPrint(
          'PostRepository: AI result notification skipped/failed for post $postId (status: $postStatus)',
        );
      }
    } catch (e) {
      debugPrint('PostRepository: Error sending AI result notification - $e');
    }
  }

  Future<void> _notifyAuthorPostPublished({
    required String userId,
    required String postId,
    String? title,
    String? body,
  }) async {
    try {
      final trimmedTitle = title?.trim();
      final trimmedBody = body?.trim();
      final preview = (trimmedTitle != null && trimmedTitle.isNotEmpty)
          ? trimmedTitle
          : (trimmedBody != null && trimmedBody.isNotEmpty)
          ? (trimmedBody.length > 50
                ? '${trimmedBody.substring(0, 50)}...'
                : trimmedBody)
          : '';

      await _notificationRepository.createNotification(
        userId: userId,
        type: 'post_published',
        title: 'Post Published',
        body: preview.isNotEmpty
            ? 'Your post "$preview" is now live.'
            : 'Your post is now live.',
        postId: postId,
      );
    } catch (e) {
      debugPrint(
        'PostRepository: Failed to notify author for published post $postId - $e',
      );
    }
  }

  /// Award 0.01 ROO for the daily post reward — once per calendar day per user.
  /// Skips silently if the user already received the reward today.
  Future<void> _awardDailyPostRoo(
    WalletRepository walletRepo,
    String userId,
    String postId,
  ) async {
    final today = DateTime.now().toUtc();
    final todayStart = DateTime.utc(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todaysTxs = await _client
        .from('roocoin_transactions')
        .select('metadata')
        .eq('to_user_id', userId)
        .gte('created_at', todayStart.toIso8601String())
        .lt('created_at', todayEnd.toIso8601String());

    final alreadyRewarded = (todaysTxs as List).any((tx) {
      final metadata = tx['metadata'];
      if (metadata is Map) {
        return metadata['activityType'] == RoobitActivityType.postCreate;
      }
      return false;
    });

    if (alreadyRewarded) {
      debugPrint(
        'PostRepository: Daily post ROO already awarded to $userId today',
      );
      return;
    }

    await walletRepo.earnRoo(
      userId: userId,
      activityType: RoobitActivityType.postCreate,
      referencePostId: postId,
    );
  }
}
