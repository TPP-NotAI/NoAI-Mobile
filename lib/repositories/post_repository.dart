import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'media_repository.dart';
import 'tag_repository.dart';
import 'mention_repository.dart';

/// Repository for post-related Supabase operations.
class PostRepository {
  final _client = SupabaseService().client;
  final MediaRepository _mediaRepository = MediaRepository();
  final TagRepository _tagRepository = TagRepository();
  final MentionRepository _mentionRepository = MentionRepository();

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
            reaction
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
              tag
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
              reaction
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
                tag
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
            reaction
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
              tag
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
            reaction
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
              tag
            )
          ),
          mentions (
            mentioned_user_id
          )
        ''')
        .eq('author_id', userId)
        .eq('status', 'published')
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
              reaction
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
                tag
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

    final results = await Future.wait([postsFuture, repostsFuture]);
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
    List<String>? mediaUrls, // URLs of uploaded media
    List<String>? mediaTypes, // 'image' or 'video' for each media
    List<String>? tags, // Tag names (hashtags/topics)
    String? location,
    List<String>? mentionedUserIds,
  }) async {
    try {
      // Create the post first
      final postData = {
        'author_id': authorId,
        'body': body,
        'title': title,
        'body_format': bodyFormat,
        'status': 'published',
        'location': location, // Added location
      };

      final response = await _client
          .from(SupabaseConfig.postsTable)
          .insert(postData)
          .select('id')
          .single();

      final postId = response['id'] as String;

      // Add media attachments
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        for (var i = 0; i < mediaUrls.length; i++) {
          final mediaType = (mediaTypes != null && i < mediaTypes.length)
              ? mediaTypes[i]
              : 'image';
          await _mediaRepository.createPostMedia(
            postId: postId,
            mediaType: mediaType,
            storagePath: mediaUrls[i],
          );
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

      // Small delay to ensure DB triggers/replication settle before fetching full post
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch the complete post with all relations
      return await getPost(postId, currentUserId: authorId);
    } catch (e) {
      debugPrint('PostRepository: Error creating post - $e');
      return null;
    }
  }

  /// Delete a post (soft delete by setting status to 'removed').
  Future<bool> deletePost(String postId) async {
    try {
      await _client
          .from(SupabaseConfig.postsTable)
          .update({'status': 'removed'})
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('PostRepository: Error deleting post - $e');
      return false;
    }
  }

  /// Unpublish a post (set status to 'draft').
  Future<bool> unpublishPost(String postId) async {
    try {
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

  /// Update a post's content.
  Future<bool> updatePost({
    required String postId,
    String? body,
    String? title,
    String? location,
  }) async {
    try {
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
}
