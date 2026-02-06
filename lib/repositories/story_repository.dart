import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/supabase_config.dart';
import '../models/story.dart';
import '../models/story_media_input.dart';
import '../models/user.dart' as noai_user;
import '../services/supabase_service.dart';
import '../services/ai_detection_service.dart';
import '../models/ai_detection_result.dart';
import 'notification_repository.dart';

/// Repository for stories/statuses backed by Supabase.
class StoryRepository {
  final SupabaseClient _client = SupabaseService().client;
  final AiDetectionService _aiDetectionService = AiDetectionService();
  final NotificationRepository _notificationRepository = NotificationRepository();

  /// Fetch active stories for the current user and the accounts they follow.
  ///
  /// Stories are filtered by `expires_at > now()` and ordered by newest first.
  Future<List<Story>> fetchFeedStories({required String currentUserId}) async {
    // Collect the set of user IDs to include: self + following.
    final followingResponse = await _client
        .from(SupabaseConfig.followsTable)
        .select('following_id')
        .eq('follower_id', currentUserId);

    final userIds = <String>{currentUserId};
    for (final row in followingResponse as List) {
      final id = row['following_id'] as String?;
      if (id != null) userIds.add(id);
    }

    if (userIds.isEmpty) return [];

    // Fetch story IDs already viewed by the current user.
    final viewedResponse = await _client
        .from(SupabaseConfig.storyViewsTable)
        .select('story_id')
        .eq('viewer_id', currentUserId);
    final viewedIds = <String>{
      for (final row in viewedResponse as List)
        if (row['story_id'] != null) row['story_id'] as String,
    };

    // Fetch active stories with author profile joined.
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final orCondition = userIds.map((id) => 'user_id.eq.$id').join(',');
    final storiesResponse = await _client
        .from(SupabaseConfig.storiesTable)
        .select('''
          *,
          profiles:profiles!stories_user_id_fkey (
            user_id,
            username,
            display_name,
            avatar_url,
            verified_human
          ),
          reactions:reactions!reactions_story_id_fkey (
            user_id,
            reaction_type
          )
        ''')
        .or(orCondition)
        .gt('expires_at', nowIso)
        // Only show passed stories, legacy stories (null status), or the user's own stories that aren't flagged
        .or('status.eq.pass,status.is.null,user_id.eq.$currentUserId')
        .neq(
          'status',
          'flagged',
        ) // Never show explicitly flagged stories in the main feed
        .order('created_at', ascending: false);

    return (storiesResponse as List)
        .map(
          (row) => Story.fromSupabase(
            row as Map<String, dynamic>,
            isViewed: viewedIds.contains(row['id'] as String),
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  /// Mark a story as viewed for the current user.
  ///
  /// Returns true if a new view was recorded (not previously viewed).
  Future<bool> markStoryViewed({
    required String storyId,
    required String viewerId,
  }) async {
    try {
      // Don't count owner's own views
      final story = await _client
          .from(SupabaseConfig.storiesTable)
          .select('user_id')
          .eq('id', storyId)
          .maybeSingle();

      if (story != null && story['user_id'] == viewerId) {
        return false;
      }

      final existing = await _client
          .from(SupabaseConfig.storyViewsTable)
          .select('id')
          .eq('story_id', storyId)
          .eq('viewer_id', viewerId)
          .maybeSingle();

      if (existing != null) return false;

      await _client.from(SupabaseConfig.storyViewsTable).insert({
        'story_id': storyId,
        'viewer_id': viewerId,
      });
      return true;
    } catch (e) {
      debugPrint('StoryRepository: failed to mark viewed - $e');
      return false;
    }
  }

  /// Create one or more stories for the current user.
  ///
  /// Each media item becomes its own story row. Stories expire 24h after creation.
  Future<List<Story>> createStories({
    required String userId,
    required List<StoryMediaInput> mediaItems,
    String? caption,
    String? backgroundColor,
    String? textOverlay,
    Map<String, dynamic>? textPosition,
  }) async {
    if (mediaItems.isEmpty) return [];
    try {
      final expiresAt = DateTime.now().add(const Duration(hours: 24)).toUtc();
      final payload = mediaItems
          .map(
            (media) => {
              'user_id': userId,
              'media_url': media.url,
              'media_type': media.mediaType,
              'caption': caption,
              'background_color': backgroundColor,
              'text_overlay': textOverlay,
              'text_position': textPosition,
              'expires_at': expiresAt.toIso8601String(),
              'status': 'review', // Start under review for AI moderation
            },
          )
          .toList();

      final response = await _client
          .from(SupabaseConfig.storiesTable)
          .insert(payload)
          .select('''
            *,
            profiles:profiles!stories_user_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human
            ),
            reactions:reactions!reactions_story_id_fkey (
              user_id,
              reaction_type
            )
          ''');

      final stories = (response as List)
          .map((row) => Story.fromSupabase(row as Map<String, dynamic>))
          .toList();

      return stories;
    } catch (e) {
      debugPrint('StoryRepository: failed to create stories - $e');
      return [];
    }
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$url';
  }

  /// Backwards compatible single-story creator.
  Future<Story?> createStory({
    required String userId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    String? backgroundColor,
    String? textOverlay,
    Map<String, dynamic>? textPosition,
  }) async {
    final stories = await createStories(
      userId: userId,
      mediaItems: [StoryMediaInput(url: mediaUrl, mediaType: mediaType)],
      caption: caption,
      backgroundColor: backgroundColor,
      textOverlay: textOverlay,
      textPosition: textPosition,
    );
    return stories.isNotEmpty ? stories.first : null;
  }

  /// Delete a story owned by the current user.
  Future<bool> deleteStory({
    required String storyId,
    required String userId,
  }) async {
    try {
      // First verify ownership
      final story = await _client
          .from(SupabaseConfig.storiesTable)
          .select('user_id')
          .eq('id', storyId)
          .maybeSingle();

      if (story == null || story['user_id'] != userId) {
        debugPrint('StoryRepository: Story not found or not owned by user');
        return false;
      }

      // Delete related records first
      // Delete story views
      await _client
          .from(SupabaseConfig.storyViewsTable)
          .delete()
          .eq('story_id', storyId);

      // Delete moderation cases
      await _client
          .from(SupabaseConfig.moderationCasesTable)
          .delete()
          .eq('story_id', storyId);

      // Finally delete the story
      final deleted = await _client
          .from(SupabaseConfig.storiesTable)
          .delete()
          .eq('id', storyId)
          .select('id')
          .maybeSingle();

      return deleted != null;
    } catch (e) {
      debugPrint('StoryRepository: failed to delete story - $e');
      return false;
    }
  }

  /// Fetch the list of viewers (profiles) for a given story.
  Future<List<Map<String, dynamic>>> fetchStoryViewers({
    required String storyId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConfig.storyViewsTable)
          .select('''
            viewer:profiles!story_views_viewer_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url,
              verified_human,
              status,
              last_active_at,
              created_at
            ),
            viewed_at
          ''')
          .eq('story_id', storyId)
          .neq(
            'viewer_id',
            _client.auth.currentUser?.id ?? '',
          ) // Ensure self is not returned
          .order('viewed_at', ascending: false);

      return (response as List).map((row) {
        return {
          'user': noai_user.User.fromSupabase(
            row['viewer'] as Map<String, dynamic>,
          ),
          'viewedAt': DateTime.parse(row['viewed_at'] as String),
        };
      }).toList();
    } catch (e) {
      debugPrint('StoryRepository: failed to fetch viewers - $e');
      return [];
    }
  }

  /// Minimum character count for AI detection on captions.
  /// Short captions are skipped for text detection (image detection still runs).
  static const int _minAiDetectionLength = 50;

  /// Run AI detection for a story in the background.
  /// Returns the confidence score on success, or null on failure.
  Future<Map<String, dynamic>?> runAiDetection({
    required String storyId,
    required String authorId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    try {
      final trimmedCaption = caption?.trim() ?? '';
      // Only run text detection if caption is long enough
      final hasText = trimmedCaption.length >= _minAiDetectionLength;
      final hasMedia = mediaType == 'image' || mediaType == 'video';

      if (trimmedCaption.isNotEmpty && trimmedCaption.length < _minAiDetectionLength) {
        debugPrint(
          'StoryRepository: Skipping text detection for short caption on story $storyId '
          '(${trimmedCaption.length} chars < $_minAiDetectionLength)',
        );
      }

      AiDetectionResult? textResult;
      AiDetectionResult? mediaResult;

      // Detect text if present and long enough
      if (hasText) {
        textResult = await _aiDetectionService.detectText(trimmedCaption);
      }

      // Detect media if it's an image
      if (hasMedia && mediaType == 'image') {
        try {
          // Download the image file from URL
          final tempDir = await getTemporaryDirectory();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = '${tempDir.path}/$fileName';

          final response = await http.get(Uri.parse(_resolveUrl(mediaUrl)));
          if (response.statusCode == 200) {
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            mediaResult = await _aiDetectionService.detectImage(file);

            // Clean up temp file
            try {
              await file.delete();
            } catch (e) {
              debugPrint('StoryRepository: Failed to clean up temp file - $e');
            }
          } else {
            debugPrint(
              'StoryRepository: Failed to download image from $mediaUrl - status ${response.statusCode}',
            );
          }
        } catch (e) {
          debugPrint('StoryRepository: Error downloading/detecting image - $e');
        }
      }

      // Combine results - if either text or media is flagged, flag the story
      final double aiProbability;
      final AiDetectionResult? primaryResult = textResult ?? mediaResult;

      if (primaryResult != null) {
        // Convert API confidence to AI probability
        final bool isAiResult =
            primaryResult.result == 'AI-GENERATED' ||
            primaryResult.result == 'LIKELY AI-GENERATED';
        aiProbability = isAiResult
            ? primaryResult.confidence
            : 100 - primaryResult.confidence;
      } else {
        // No content to detect, consider it passed
        await _updateAiScore(storyId: storyId, confidence: 0.0, status: 'pass');
        return {'score': 0.0, 'status': 'pass'};
      }

      // Determine status based on AI probability (aligned with API docs)
      final String status;
      if (aiProbability > 95) {
        status = 'flagged'; // Auto-block high-confidence AI content
      } else if (aiProbability > 75) {
        status = 'flagged'; // Flag for review
      } else if (aiProbability > 60) {
        status = 'review'; // Add transparency label but allow
      } else {
        status = 'pass'; // Auto-allow safe content
      }

      await _updateAiScore(
        storyId: storyId,
        confidence: aiProbability,
        status: status,
        analysisId: primaryResult.analysisId,
        aiMetadata: {
          'consensus_strength': primaryResult.consensusStrength,
          'rationale': primaryResult.rationale,
          'combined_evidence': primaryResult.combinedEvidence,
          'classification': primaryResult.result,
        },
      );

      // Send notification to author about AI check result
      await _sendAiResultNotification(
        userId: authorId,
        storyId: storyId,
        storyStatus: status,
        aiProbability: aiProbability,
      );

      // Create moderation case if flagged or review required
      if (status == 'flagged' || status == 'review') {
        await _createModerationCase(
          storyId: storyId,
          authorId: authorId,
          aiConfidence: aiProbability,
          aiModel: primaryResult.analysisId,
          aiMetadata: {
            'consensus_strength': primaryResult.consensusStrength,
            'rationale': primaryResult.rationale,
            'combined_evidence': primaryResult.combinedEvidence,
            'classification': primaryResult.result,
          },
        );
      }

      return {'score': aiProbability, 'status': status};
    } catch (e) {
      debugPrint(
        'StoryRepository: AI detection failed for story $storyId - $e',
      );
      return null;
    }
  }

  /// Update a story's AI score and status.
  Future<bool> _updateAiScore({
    required String storyId,
    required double confidence,
    required String status,
    String? analysisId,
    Map<String, dynamic>? aiMetadata,
  }) async {
    try {
      final updates = <String, dynamic>{
        'ai_score': confidence,
        'status': status,
      };

      if (analysisId != null) {
        updates['verification_session_id'] = analysisId;
      }
      if (aiMetadata != null) {
        updates['ai_metadata'] = aiMetadata;
      }

      await _client
          .from(SupabaseConfig.storiesTable)
          .update(updates)
          .eq('id', storyId);
      debugPrint(
        'StoryRepository: Updated AI score - storyId=$storyId, score=$confidence, status=$status',
      );
      return true;
    } catch (e) {
      debugPrint('StoryRepository: Error updating AI score - $e');
      return false;
    }
  }

  /// Create a moderation case for an AI-flagged story.
  Future<void> _createModerationCase({
    required String storyId,
    required String authorId,
    required double aiConfidence,
    String? aiModel,
    Map<String, dynamic>? aiMetadata,
  }) async {
    try {
      // Check if a case already exists
      final existing = await _client
          .from(SupabaseConfig.moderationCasesTable)
          .select('id')
          .eq('story_id', storyId)
          .maybeSingle();

      if (existing != null) {
        debugPrint(
          'StoryRepository: Moderation case already exists for story $storyId',
        );
        return;
      }

      await _client.from(SupabaseConfig.moderationCasesTable).insert({
        'story_id': storyId,
        'reported_user_id': authorId,
        'reason': 'ai_generated',
        'source': 'ai',
        'ai_confidence': aiConfidence,
        'ai_model': aiModel,
        'ai_metadata': aiMetadata ?? {},
        'status': 'pending',
        'priority': 'normal',
        'description':
            'Automated AI detection flagged this story with ${aiConfidence.toStringAsFixed(1)}% confidence.',
      });

      debugPrint('StoryRepository: Created moderation case for story $storyId');
    } catch (e) {
      debugPrint(
        'StoryRepository: Error creating moderation case for story $storyId - $e',
      );
    }
  }

  /// Send a notification to the story author about AI detection result.
  Future<void> _sendAiResultNotification({
    required String userId,
    required String storyId,
    required String storyStatus,
    required double aiProbability,
  }) async {
    try {
      String title;
      String body;
      String type;

      switch (storyStatus) {
        case 'pass':
          // Don't notify for passed stories - too noisy
          return;
        case 'review':
          title = 'Story Under Review';
          body = 'Your story is being reviewed by our moderation team.';
          type = 'mention'; // Using 'mention' as valid DB type for system notifications
          break;
        case 'flagged':
          title = 'Story Not Published';
          body = 'Your story was flagged as potentially AI-generated (${aiProbability.toStringAsFixed(0)}% confidence).';
          type = 'mention';
          break;
        default:
          return; // Don't send notification for unknown status
      }

      await _notificationRepository.createNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        storyId: storyId,
      );

      debugPrint(
        'StoryRepository: Sent AI result notification to $userId for story $storyId (status: $storyStatus)',
      );
    } catch (e) {
      debugPrint(
        'StoryRepository: Error sending AI result notification - $e',
      );
    }
  }
}
