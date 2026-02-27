import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';

/// Repository for post/comment appeal operations.
class AppealRepository {
  final _client = SupabaseService().client;

  /// Find or create a moderation case for an AI-flagged post, comment, or story.
  /// Returns the moderation case ID, or null on failure.
  Future<String?> getOrCreateModerationCase({
    String? postId,
    String? commentId,
    String? storyId,
    String? messageId,
    required String reportedUserId,
    required double aiConfidence,
  }) async {
    assert(
      [postId, commentId, storyId, messageId].where((v) => v != null).length == 1,
      'Provide exactly one of postId, commentId, storyId, or messageId',
    );

    final field = postId != null
        ? 'post_id'
        : commentId != null
        ? 'comment_id'
        : messageId != null
        ? 'message_id'
        : 'story_id';
    final contentId = postId ?? commentId ?? storyId ?? messageId;

    try {
      final existing = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select('id')
          .eq(field, contentId!)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      final response = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .insert({
            if (postId != null) 'post_id': postId,
            if (commentId != null) 'comment_id': commentId,
            if (storyId != null) 'story_id': storyId,
            if (messageId != null) 'message_id': messageId,
            'reported_user_id': reportedUserId,
            'reason': 'ai_generated',
            'source': 'ai',
            'ai_confidence': aiConfidence,
            'status': 'pending',
            'priority': 'normal',
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint(
        'AppealRepository: Error getting/creating moderation case - $e',
      );
      return null;
    }
  }

  /// Submit an appeal for a moderation case.
  /// Returns true on success.
  Future<bool> submitAppeal({
    required String userId,
    required String moderationCaseId,
    required String statement,
  }) async {
    try {
      await _client.from(SupabaseConfig.appealsTable).insert({
        'user_id': userId,
        'moderation_case_id': moderationCaseId,
        'statement': statement,
      });
      return true;
    } catch (e) {
      debugPrint('AppealRepository: Error submitting appeal - $e');
      return false;
    }
  }

  /// Check if user already has a pending appeal for a given post, comment, or story.
  Future<bool> hasExistingAppeal({
    required String userId,
    String? postId,
    String? commentId,
    String? storyId,
    String? messageId,
  }) async {
    assert(
      [postId, commentId, storyId, messageId].where((v) => v != null).length == 1,
      'Provide exactly one of postId, commentId, storyId, or messageId',
    );

    final field = postId != null
        ? 'post_id'
        : commentId != null
        ? 'comment_id'
        : messageId != null
        ? 'message_id'
        : 'story_id';
    final contentId = postId ?? commentId ?? storyId ?? messageId;

    try {
      final result = await _client
          .from(SupabaseConfig.appealsTable)
          .select('id')
          .eq('user_id', userId)
          .eq(
            'moderation_case_id',
            _client
                .from(SupabaseConfig.moderationCasesTable)
                .select('id')
                .eq(field, contentId!),
          )
          .maybeSingle();

      return result != null;
    } catch (e) {
      // Fallback: query moderation_cases first, then check appeals
      try {
        final modCase = await _client
            .from(SupabaseConfig.moderationCasesTable)
            .select('id')
            .eq(field, contentId!)
            .maybeSingle();

        if (modCase == null) return false;

        final appeal = await _client
            .from(SupabaseConfig.appealsTable)
            .select('id')
            .eq('user_id', userId)
            .eq('moderation_case_id', modCase['id'] as String)
            .maybeSingle();

        return appeal != null;
      } catch (e2) {
        debugPrint('AppealRepository: Error checking existing appeal - $e2');
        return false;
      }
    }
  }
}
