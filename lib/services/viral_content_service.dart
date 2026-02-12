import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';

/// Service to detect and reward viral content
class ViralContentService {
  final _client = SupabaseService().client;
  final _walletRepo = WalletRepository();

  // Viral thresholds
  static const int viralViewThreshold = 10000;

  /// Check if a post has gone viral and reward if not already rewarded
  /// A post is considered viral if it has:
  /// - 10,000+ views
  Future<bool> checkAndRewardViralPost(String postId, String authorId) async {
    try {
      // Check if already rewarded for this post
      final existingReward = await _client
          .from('roocoin_transactions')
          .select('id')
          .eq('to_user_id', authorId)
          .eq('reference_post_id', postId)
          .contains('metadata', {
            'activityType': RookenActivityType.contentViral,
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
          .select('id, author_id, views_count')
          .eq('id', postId)
          .single();
      final viewsCount = post['views_count'] as int? ?? 0;

      // Check if viral
      final isViral = viewsCount >= viralViewThreshold;

      if (isViral) {
        // Award 100 ROOK for viral content
        await _walletRepo.earnRoo(
          userId: authorId,
          activityType: RookenActivityType.contentViral,
          referencePostId: postId,
          metadata: {
            'views': viewsCount,
            'viral_date': DateTime.now().toIso8601String(),
          },
        );

        debugPrint(
          'ViralContentService: Awarded 100 ROOK to $authorId for viral post $postId '
          '(views: $viewsCount)',
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
          .select('views_count')
          .eq('id', postId)
          .single();
      final viewsCount = post['views_count'] as int? ?? 0;
      final viewsProgress = (viewsCount / viralViewThreshold * 100)
          .clamp(0, 100)
          .round();

      return {
        'overall_progress': viewsProgress,
        'views_progress': viewsProgress,
        'views_count': viewsCount,
        'is_viral': viewsProgress >= 100,
      };
    } catch (e) {
      debugPrint('ViralContentService: Error getting viral progress - $e');
      return {
        'overall_progress': 0,
        'views_progress': 0,
        'views_count': 0,
        'is_viral': false,
      };
    }
  }
}
