import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Represents a single boost record joined with its post data.
class BoostRecord {
  final String id;
  final String postId;
  final String authorId;
  final int targetUserCount;
  final int actualReachedCount;
  final double costRc;
  final String status; // pending, active, completed, failed, cancelled
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  // Post join data (nullable — only populated when fetched with post join)
  final String? postTitle;
  final int postViews;
  final int postLikes;
  final int postComments;
  final int postReposts;

  const BoostRecord({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.targetUserCount,
    required this.actualReachedCount,
    required this.costRc,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.postTitle,
    this.postViews = 0,
    this.postLikes = 0,
    this.postComments = 0,
    this.postReposts = 0,
  });

  factory BoostRecord.fromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? postRow,
  }) {
    final postBody = postRow?['body'] as String? ?? '';
    final firstLine = postBody.split('\n').first;
    return BoostRecord(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      authorId: row['author_id'] as String,
      targetUserCount: (row['target_user_count'] as num).toInt(),
      actualReachedCount: (row['actual_reached_count'] as num? ?? 0).toInt(),
      costRc: (row['cost_rc'] as num).toDouble(),
      status: row['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(row['created_at'] as String),
      startedAt: row['started_at'] != null
          ? DateTime.tryParse(row['started_at'] as String)
          : null,
      completedAt: row['completed_at'] != null
          ? DateTime.tryParse(row['completed_at'] as String)
          : null,
      postTitle: postRow?['title'] as String? ??
          (firstLine.isNotEmpty ? firstLine : null),
      postViews: (postRow?['views_count'] as num? ?? 0).toInt(),
      postLikes: (postRow?['likes_count'] as num? ?? 0).toInt(),
      postComments: (postRow?['comments_count'] as num? ?? 0).toInt(),
      postReposts: (postRow?['reposts_count'] as num? ?? 0).toInt(),
    );
  }
}

class BoostRepository {
  final _client = SupabaseService().client;

  /// Creates a new boost record in `post_boosts`.
  /// Returns the new boost ID, or null on failure.
  Future<String?> createBoost({
    required String postId,
    required String authorId,
    required int targetUserCount,
    required double costRc,
  }) async {
    try {
      final row = await _client
          .from('post_boosts')
          .insert({
            'post_id': postId,
            'author_id': authorId,
            'target_user_count': targetUserCount,
            'cost_rc': costRc,
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return row['id'] as String;
    } catch (e) {
      debugPrint('BoostRepository: Error creating boost - $e');
      return null;
    }
  }

  /// Selects [targetUserCount] random user IDs (excluding [authorId]) and
  /// records them as recipients. Returns the list of selected user IDs.
  Future<List<String>> selectAndInsertRecipients({
    required String boostId,
    required String authorId,
    required int targetUserCount,
  }) async {
    try {
      // Fetch random active users excluding the author
      final rows = await _client
          .from('profiles')
          .select('user_id')
          .neq('user_id', authorId)
          .eq('status', 'active')
          .limit(targetUserCount);

      final userIds = (rows as List<dynamic>)
          .map((r) => r['user_id'] as String)
          .toList();

      if (userIds.isEmpty) return [];

      // Insert recipients in batches to stay within DB limits
      const batchSize = 100;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        await _client.from('post_boost_recipients').insert(
          batch.map((uid) => {
            'boost_id': boostId,
            'user_id': uid,
            'selection_reason': 'engagement',
          }).toList(),
        );
      }

      // Update actual_reached_count on the boost record
      await _client
          .from('post_boosts')
          .update({
            'actual_reached_count': userIds.length,
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', boostId);

      return userIds;
    } catch (e) {
      debugPrint('BoostRepository: Error inserting recipients - $e');
      // Mark boost as failed
      try {
        await _client
            .from('post_boosts')
            .update({'status': 'failed', 'failed_reason': e.toString()})
            .eq('id', boostId);
      } catch (_) {}
      return [];
    }
  }

  /// Fetches all boosts for [userId], joined with post engagement data.
  /// Optionally filtered to a single [postId].
  Future<List<BoostRecord>> getBoostsForUser(
    String userId, {
    String? postId,
  }) async {
    try {
      var query = _client
          .from('post_boosts')
          .select()
          .eq('author_id', userId);

      if (postId != null) {
        query = query.eq('post_id', postId);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(100);
      final boostList = rows as List<dynamic>;

      if (boostList.isEmpty) return [];

      // Fetch associated post data in one query
      final postIds = boostList
          .map((r) => r['post_id'] as String)
          .toSet()
          .toList();

      final postRows = await _client
          .from('posts')
          .select(
            'id, title, body, views_count, likes_count, comments_count, reposts_count',
          )
          .inFilter('id', postIds);

      final postMap = <String, Map<String, dynamic>>{};
      for (final p in postRows as List<dynamic>) {
        postMap[p['id'] as String] = p as Map<String, dynamic>;
      }

      return boostList
          .map(
            (r) => BoostRecord.fromRow(
              r as Map<String, dynamic>,
              postRow: postMap[r['post_id'] as String],
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('BoostRepository: Error fetching boosts - $e');
      return [];
    }
  }

  /// Returns the set of post IDs the user has ever boosted.
  /// Used by [PostBoostCache] to mark the Sponsored badge.
  Future<Set<String>> getBoostedPostIds(String userId) async {
    try {
      final rows = await _client
          .from('post_boosts')
          .select('post_id')
          .eq('author_id', userId);

      return (rows as List<dynamic>)
          .map((r) => r['post_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('BoostRepository: Error fetching boosted post IDs - $e');
      return {};
    }
  }
}
