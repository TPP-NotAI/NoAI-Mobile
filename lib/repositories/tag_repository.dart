import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';

/// Represents a trending tag with post count
class TrendingTag {
  final String id;
  final String name;
  final int postCount;

  TrendingTag({
    required this.id,
    required this.name,
    required this.postCount,
  });

  factory TrendingTag.fromSupabase(Map<String, dynamic> json) {
    return TrendingTag(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      postCount: json['post_count'] as int? ?? 0,
    );
  }
}

/// Repository for handling tags/topics operations.
class TagRepository {
  final _client = SupabaseService().client;

  /// Get or create a tag by name. Returns the tag ID.
  Future<String?> getOrCreateTag(String tagName) async {
    try {
      // Normalize tag name (lowercase, trim)
      final normalizedTag = tagName.toLowerCase().trim();
      if (normalizedTag.isEmpty) return null;

      // Check if tag exists
      final existing = await _client
          .from(SupabaseConfig.tagsTable)
          .select('id')
          .eq('name', normalizedTag)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      // Create new tag
      final newTag = await _client
          .from(SupabaseConfig.tagsTable)
          .insert({'name': normalizedTag, 'slug': normalizedTag})
          .select('id')
          .single();

      return newTag['id'] as String;
    } catch (e) {
      debugPrint('TagRepository: Error getting/creating tag - $e');
      return null;
    }
  }

  /// Associate tags with a post.
  Future<bool> addTagsToPost({
    required String postId,
    required List<String> tagNames,
  }) async {
    try {
      for (final tagName in tagNames) {
        final tagId = await getOrCreateTag(tagName);
        if (tagId != null) {
          // Insert into post_tags junction table
          await _client.from(SupabaseConfig.postTagsTable).upsert({
            'post_id': postId,
            'tag_id': tagId,
          });
        }
      }
      return true;
    } catch (e) {
      debugPrint('TagRepository: Error adding tags to post - $e');
      return false;
    }
  }

  /// Remove all tags from a post.
  Future<bool> removeTagsFromPost(String postId) async {
    try {
      await _client
          .from(SupabaseConfig.postTagsTable)
          .delete()
          .eq('post_id', postId);
      return true;
    } catch (e) {
      debugPrint('TagRepository: Error removing tags from post - $e');
      return false;
    }
  }

  /// Search for tags by prefix (for autocomplete).
  Future<List<PostTag>> searchTags(String query, {int limit = 10}) async {
    try {
      final normalizedQuery = query.toLowerCase().trim();
      if (normalizedQuery.isEmpty) return [];

      final response = await _client
          .from(SupabaseConfig.tagsTable)
          .select('id, name')
          .ilike('name', '$normalizedQuery%')
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => PostTag.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('TagRepository: Error searching tags - $e');
      return [];
    }
  }

  /// Get popular/trending tags with post counts.
  Future<List<TrendingTag>> getTrendingTags({int limit = 20}) async {
    try {
      // Get tags with post counts using RPC or aggregate query
      final response = await _client
          .from(SupabaseConfig.tagsTable)
          .select('id, name, post_tags(count)')
          .limit(limit);

      final tags = (response as List<dynamic>).map((json) {
        final postTagsData = json['post_tags'] as List<dynamic>? ?? [];
        final count = postTagsData.isNotEmpty
            ? (postTagsData.first['count'] as int? ?? 0)
            : 0;
        return TrendingTag(
          id: json['id']?.toString() ?? '',
          name: json['name']?.toString() ?? '',
          postCount: count,
        );
      }).toList();

      // Sort by post count descending
      tags.sort((a, b) => b.postCount.compareTo(a.postCount));
      return tags;
    } catch (e) {
      debugPrint('TagRepository: Error getting trending tags - $e');
      return [];
    }
  }

  /// Get posts by tag name.
  Future<List<Post>> getPostsByTag(String tagName, {String? currentUserId, int limit = 50}) async {
    try {
      final normalizedTag = tagName.toLowerCase().trim();

      // First get the tag ID
      final tagResponse = await _client
          .from(SupabaseConfig.tagsTable)
          .select('id')
          .eq('name', normalizedTag)
          .maybeSingle();

      if (tagResponse == null) return [];

      final tagId = tagResponse['id'] as String;

      // Get post IDs that have this tag
      final postTagsResponse = await _client
          .from(SupabaseConfig.postTagsTable)
          .select('post_id')
          .eq('tag_id', tagId);

      final postIds = (postTagsResponse as List<dynamic>)
          .map((pt) => pt['post_id'] as String)
          .toList();

      if (postIds.isEmpty) return [];

      // Fetch full posts with all related data
      final postsResponse = await _client
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
            reactions!reactions_post_id_fkey (
              user_id,
              reaction_type
            ),
            comments!comments_post_id_fkey (
              id
            ),
            post_media (
              id,
              post_id,
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
            )
          ''')
          .inFilter('id', postIds)
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(limit);

      return (postsResponse as List<dynamic>)
          .map((json) => Post.fromSupabase(
                json as Map<String, dynamic>,
                currentUserId: currentUserId,
              ))
          .toList();
    } catch (e) {
      debugPrint('TagRepository: Error getting posts by tag - $e');
      return [];
    }
  }

  /// Extract hashtags from text content (e.g., "#flutter #dart").
  List<String> extractHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }
}
