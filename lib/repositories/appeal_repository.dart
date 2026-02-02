import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';

/// Repository for post appeal operations.
class AppealRepository {
  final _client = SupabaseService().client;

  /// Find or create a moderation case for an AI-flagged post.
  /// Returns the moderation case ID, or null on failure.
  Future<String?> getOrCreateModerationCase({
    required String postId,
    required String reportedUserId,
    required double aiConfidence,
  }) async {
    try {
      final existing = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select('id')
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      final response = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .insert({
            'post_id': postId,
            'reported_user_id': reportedUserId,
            'reason': 'ai_content',
            'source': 'ai',
            'ai_confidence': aiConfidence,
            'status': 'pending',
            'priority': 'normal',
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('AppealRepository: Error getting/creating moderation case - $e');
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

  /// Check if user already has a pending appeal for a given post.
  Future<bool> hasExistingAppeal({
    required String userId,
    required String postId,
  }) async {
    try {
      final result = await _client
          .from(SupabaseConfig.appealsTable)
          .select('id')
          .eq('user_id', userId)
          .eq('moderation_case_id', _client
              .from(SupabaseConfig.moderationCasesTable)
              .select('id')
              .eq('post_id', postId))
          .maybeSingle();

      return result != null;
    } catch (e) {
      // Fallback: query moderation_cases first, then check appeals
      try {
        final modCase = await _client
            .from(SupabaseConfig.moderationCasesTable)
            .select('id')
            .eq('post_id', postId)
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
