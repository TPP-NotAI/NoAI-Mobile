import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../repositories/wallet_repository.dart';
import '../services/roocoin_service.dart';

/// Service to detect and reward viral content
class ViralContentService {
  final _client = SupabaseService().client;
  final _walletRepo = WalletRepository();

  // Viral thresholds
  static const int viralLikeThreshold = 1000;
  static const int viralRepostThreshold = 100;
  static const int viralCommentThreshold = 200;

  /// Check if a post has gone viral and reward if not already rewarded
  /// A post is considered viral if it has:
  /// - 1000+ likes OR
  /// - 100+ reposts OR
  /// - 200+ comments
  Future<bool> checkAndRewardViralPost(String postId, String authorId) async {
    try {
      // Check if already rewarded for this post
      final existingReward = await _client
          .from('roocoin_transactions')
          .select('id')
          .eq('to_user_id', authorId)
          .eq('reference_post_id', postId)
          .contains('metadata', {
            'activityType': RoocoinActivityType.contentViral,
          })
          .maybeSingle();

      if (existingReward != null) {
        debugPrint(
          'ViralContentService: Post $postId already rewarded for going viral',
        );
        return false;
      }

      // Get post engagement metrics
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('id, author_id, likes_count, comments_count')
          .eq('id', postId)
          .single();

      // Get repost count
      final reposts = await _client
          .from(SupabaseConfig.repostsTable)
          .select('id')
          .eq('post_id', postId);

      final likesCount = post['likes_count'] as int? ?? 0;
      final commentsCount = post['comments_count'] as int? ?? 0;
      final repostsCount = (reposts as List).length;

      // Check if viral
      final isViral =
          likesCount >= viralLikeThreshold ||
          repostsCount >= viralRepostThreshold ||
          commentsCount >= viralCommentThreshold;

      if (isViral) {
        // Award 100 ROO for viral content
        await _walletRepo.earnRoo(
          userId: authorId,
          activityType: RoocoinActivityType.contentViral,
          referencePostId: postId,
          metadata: {
            'likes': likesCount,
            'reposts': repostsCount,
            'comments': commentsCount,
            'viral_date': DateTime.now().toIso8601String(),
          },
        );

        debugPrint(
          'ViralContentService: Awarded 100 ROO to $authorId for viral post $postId '
          '(likes: $likesCount, reposts: $repostsCount, comments: $commentsCount)',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('ViralContentService: Error checking viral status - $e');
      return false;
    }
  }

  /// Get progress towards viral status (0-100%)
  Future<Map<String, dynamic>> getViralProgress(String postId) async {
    try {
      final post = await _client
          .from(SupabaseConfig.postsTable)
          .select('likes_count, comments_count')
          .eq('id', postId)
          .single();

      final reposts = await _client
          .from(SupabaseConfig.repostsTable)
          .select('id')
          .eq('post_id', postId);

      final likesCount = post['likes_count'] as int? ?? 0;
      final commentsCount = post['comments_count'] as int? ?? 0;
      final repostsCount = (reposts as List).length;

      final likesProgress = (likesCount / viralLikeThreshold * 100)
          .clamp(0, 100)
          .round();
      final repostsProgress = (repostsCount / viralRepostThreshold * 100)
          .clamp(0, 100)
          .round();
      final commentsProgress = (commentsCount / viralCommentThreshold * 100)
          .clamp(0, 100)
          .round();

      final maxProgress = [
        likesProgress,
        repostsProgress,
        commentsProgress,
      ].reduce((a, b) => a > b ? a : b);

      return {
        'overall_progress': maxProgress,
        'likes_progress': likesProgress,
        'reposts_progress': repostsProgress,
        'comments_progress': commentsProgress,
        'likes_count': likesCount,
        'reposts_count': repostsCount,
        'comments_count': commentsCount,
        'is_viral': maxProgress >= 100,
      };
    } catch (e) {
      debugPrint('ViralContentService: Error getting viral progress - $e');
      return {
        'overall_progress': 0,
        'likes_progress': 0,
        'reposts_progress': 0,
        'comments_progress': 0,
        'likes_count': 0,
        'reposts_count': 0,
        'comments_count': 0,
        'is_viral': false,
      };
    }
  }
}
