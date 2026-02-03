import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';

/// Repository for user report operations.
class ReportRepository {
  final _client = SupabaseService().client;

  /// Submit a report for a post.
  /// Returns true if successful.
  Future<bool> reportPost({
    required String reporterId,
    required String postId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    debugPrint(
      'ReportRepository: Submitting report for post=$postId, reason=$reason',
    );

    try {
      await _client.from(SupabaseConfig.userReportsTable).insert({
        'reporter_id': reporterId,
        'post_id': postId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'details': details,
      });
      debugPrint('ReportRepository: Report submitted successfully');
      return true;
    } catch (e) {
      debugPrint('ReportRepository: Error submitting report - $e');
      return false;
    }
  }

  /// Submit a report for a comment.
  /// Returns true if successful.
  Future<bool> reportComment({
    required String reporterId,
    required String commentId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    debugPrint(
      'ReportRepository: Submitting report for comment=$commentId, reason=$reason',
    );

    try {
      await _client.from(SupabaseConfig.userReportsTable).insert({
        'reporter_id': reporterId,
        'comment_id': commentId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'details': details,
      });
      debugPrint('ReportRepository: Report submitted successfully');
      return true;
    } catch (e) {
      debugPrint('ReportRepository: Error submitting report - $e');
      return false;
    }
  }

  /// Check if user has already reported a post.
  Future<bool> hasReportedPost({
    required String reporterId,
    required String postId,
  }) async {
    final response = await _client
        .from(SupabaseConfig.userReportsTable)
        .select('id')
        .eq('reporter_id', reporterId)
        .eq('post_id', postId)
        .maybeSingle();

    return response != null;
  }

  /// Submit a report for a user.
  /// Returns true if successful.
  ///
  /// Valid reasons (must match database enum):
  /// 'spam', 'harassment', 'violence', 'inappropriate', 'copyright', 'ai_generated', 'other'
  Future<bool> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    debugPrint(
      'ReportRepository: Submitting report for user=$reportedUserId, reason=$reason',
    );

    // Map UI reasons to database enum values
    final reasonMap = {
      'Spam or fake account': 'spam',
      'Harassment or bullying': 'harassment',
      'Hate speech or symbols': 'harassment',
      'Violence or dangerous content': 'violence',
      'Nudity or sexual content': 'inappropriate',
      'Impersonation': 'spam',
      'Scam or fraud': 'spam',
      'Other': 'other',
    };

    final dbReason = reasonMap[reason] ?? 'other';

    try {
      // Use user_reports table - store details about the user report
      // Note: The table may have a check constraint requiring post_id or comment_id,
      // so we store user-only reports with details containing the context
      await _client.from(SupabaseConfig.userReportsTable).insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reason': dbReason,
        'details': details != null
            ? 'User Report: $reason - $details'
            : 'User Report: $reason',
      });
      debugPrint('ReportRepository: User report submitted successfully');
      return true;
    } catch (e) {
      debugPrint('ReportRepository: Error submitting user report - $e');
      return false;
    }
  }

  /// Check if user has already reported another user.
  Future<bool> hasReportedUser({
    required String reporterId,
    required String reportedUserId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConfig.userReportsTable)
          .select('id')
          .eq('reporter_id', reporterId)
          .eq('reported_user_id', reportedUserId)
          .isFilter('post_id', null)
          .isFilter('comment_id', null)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint(
        'ReportRepository: Error checking if user already reported - $e',
      );
      return false;
    }
  }
}
