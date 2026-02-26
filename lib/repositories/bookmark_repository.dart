import 'dart:async';

import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import '../services/activity_log_service.dart';

/// Repository for bookmark operations.
class BookmarkRepository {
  final _client = SupabaseService().client;
  final _activityLogService = ActivityLogService();

  /// Toggle bookmark on a post.
  /// Returns true if bookmarked, false if unbookmarked.
  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
  }) async {
    debugPrint('BookmarkRepository: Toggling bookmark for post=$postId, user=$userId');

    // Check if bookmark exists
    final existing = await _client
        .from(SupabaseConfig.bookmarksTable)
        .select('user_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    debugPrint('BookmarkRepository: Existing bookmark = $existing');

    if (existing != null) {
      // Remove bookmark
      debugPrint('BookmarkRepository: Removing bookmark');
      await _client
          .from(SupabaseConfig.bookmarksTable)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      unawaited(
        _activityLogService.log(
          userId: userId,
          activityType: 'bookmark',
          targetType: 'post',
          targetId: postId,
          description: 'Removed bookmark',
          metadata: {'action': 'removed'},
        ),
      );
      return false;
    } else {
      // Add bookmark
      debugPrint('BookmarkRepository: Adding bookmark');
      await _client.from(SupabaseConfig.bookmarksTable).insert({
        'post_id': postId,
        'user_id': userId,
      });
      debugPrint('BookmarkRepository: Insert successful');
      unawaited(
        _activityLogService.log(
          userId: userId,
          activityType: 'bookmark',
          targetType: 'post',
          targetId: postId,
          description: 'Bookmarked a post',
          metadata: {'action': 'added'},
        ),
      );
      return true;
    }
  }

  /// Check if user has bookmarked a post.
  Future<bool> isBookmarked({
    required String postId,
    required String userId,
  }) async {
    final response = await _client
        .from(SupabaseConfig.bookmarksTable)
        .select('user_id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  /// Get all bookmarked post IDs for a user.
  Future<Set<String>> getUserBookmarkIds({required String userId}) async {
    final response = await _client
        .from(SupabaseConfig.bookmarksTable)
        .select('post_id')
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((r) => r['post_id'] as String)
        .toSet();
  }
}
