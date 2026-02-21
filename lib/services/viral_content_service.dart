import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';
import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';

/// Service to detect and reward viral content.
/// Awards 1 ROO per 1,000 engagements milestone (likes + comments + reposts).
/// Each milestone is awarded only once per post.
class ViralContentService {
  final _client = SupabaseService().client;
  final _walletRepo = WalletRepository();

  static const int engagementsPerMilestone = 1000;

  /// Check the current engagement count for a post and award 1 ROO for each
  /// new 1,000-engagement milestone that has not yet been rewarded.
  Future<bool> checkAndRewardViralPost(String postId, String authorId) async {
    try {
      // Count total engagements using server-side COUNT to avoid loading all rows
      final results = await Future.wait([
        _client
            .from(SupabaseConfig.reactionsTable)
            .select('id')
            .eq('post_id', postId)
            .eq('reaction_type', 'like')
            .count(CountOption.exact),
        _client
            .from(SupabaseConfig.commentsTable)
            .select('id')
            .eq('post_id', postId)
            .eq('status', 'published')
            .count(CountOption.exact),
        _client
            .from(SupabaseConfig.repostsTable)
            .select('id')
            .eq('post_id', postId)
            .count(CountOption.exact),
      ]);

      final totalEngagements =
          results[0].count +
          results[1].count +
          results[2].count;

      final milestonesReached = totalEngagements ~/ engagementsPerMilestone;

      if (milestonesReached == 0) return false;

      // Count how many milestones have already been rewarded
      final existingRewards = await _client
          .from('roocoin_transactions')
          .select('id')
          .eq('to_user_id', authorId)
          .eq('reference_post_id', postId)
          .contains('metadata', {
            'activityType': RookenActivityType.contentViral,
          });

      final alreadyRewarded = (existingRewards as List).length;
      final newMilestones = milestonesReached - alreadyRewarded;

      if (newMilestones <= 0) return false;

      // Award 1 ROO for each new milestone
      for (int i = 0; i < newMilestones; i++) {
        final milestone = (alreadyRewarded + i + 1) * engagementsPerMilestone;
        await _walletRepo.earnRoo(
          userId: authorId,
          activityType: RookenActivityType.contentViral,
          referencePostId: postId,
          metadata: {
            'milestone_engagements': milestone,
            'total_engagements': totalEngagements,
            'awarded_at': DateTime.now().toIso8601String(),
          },
        );
        debugPrint(
          'ViralContentService: Awarded 1 ROO to $authorId for post $postId '
          '(${milestone} engagement milestone)',
        );
      }

      return true;
    } catch (e) {
      debugPrint('ViralContentService: Error checking viral status - $e');
      return false;
    }
  }

  /// Get progress towards the next 1,000-engagement milestone (0-100%).
  Future<Map<String, dynamic>> getViralProgress(String postId) async {
    try {
      final results = await Future.wait([
        _client
            .from(SupabaseConfig.reactionsTable)
            .select('id')
            .eq('post_id', postId)
            .eq('reaction_type', 'like')
            .count(CountOption.exact),
        _client
            .from(SupabaseConfig.commentsTable)
            .select('id')
            .eq('post_id', postId)
            .eq('status', 'published')
            .count(CountOption.exact),
        _client
            .from(SupabaseConfig.repostsTable)
            .select('id')
            .eq('post_id', postId)
            .count(CountOption.exact),
      ]);

      final totalEngagements =
          results[0].count +
          results[1].count +
          results[2].count;

      final milestonesReached = totalEngagements ~/ engagementsPerMilestone;
      final progressInCurrentMilestone =
          totalEngagements % engagementsPerMilestone;
      final progressPercent =
          (progressInCurrentMilestone / engagementsPerMilestone * 100)
              .clamp(0, 100)
              .round();

      return {
        'total_engagements': totalEngagements,
        'milestones_reached': milestonesReached,
        'progress_in_current_milestone': progressInCurrentMilestone,
        'overall_progress': progressPercent,
        'next_milestone': (milestonesReached + 1) * engagementsPerMilestone,
      };
    } catch (e) {
      debugPrint('ViralContentService: Error getting viral progress - $e');
      return {
        'total_engagements': 0,
        'milestones_reached': 0,
        'progress_in_current_milestone': 0,
        'overall_progress': 0,
        'next_milestone': engagementsPerMilestone,
      };
    }
  }
}
