import 'dart:io';
import 'dart:async';
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
import 'mention_repository.dart';

/// Repository for stories/statuses backed by Supabase.
class StoryRepository {
  final SupabaseClient _client = SupabaseService().client;
  final AiDetectionService _aiDetectionService = AiDetectionService();
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final MentionRepository _mentionRepository = MentionRepository();

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
        .inFilter('user_id', userIds.toList())
        .gt('expires_at', nowIso)
        // Match post feed behavior: show only approved stories.
        .eq('status', 'pass')
        .order('created_at', ascending: false);

    final rawRows = (storiesResponse as List).cast<Map<String, dynamic>>();
    final statusCounts = <String, int>{};
    for (final row in rawRows) {
      final status = (row['status'] as String?)?.trim().toLowerCase() ?? 'null';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    debugPrint(
      'StoryRepository: fetchFeedStories raw=${rawRows.length} '
      'for user=$currentUserId statuses=$statusCounts',
    );

    return rawRows
        .map(
          (row) => Story.fromSupabase(
            row,
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
  /// For text-only stories, pass an empty mediaItems list with textOverlay set.
  Future<List<Story>> createStories({
    required String userId,
    required List<StoryMediaInput> mediaItems,
    String? caption,
    String? backgroundColor,
    String? textOverlay,
    Map<String, dynamic>? textPosition,
  }) async {
    try {
      final expiresAt = DateTime.now().add(const Duration(hours: 24)).toUtc();

      List<Map<String, dynamic>> payload;

      if (mediaItems.isEmpty) {
        // Text-only story
        if (textOverlay == null || textOverlay.trim().isEmpty) {
          debugPrint(
            'StoryRepository: Cannot create empty story without media or text',
          );
          return [];
        }
        payload = [
          {
            'user_id': userId,
            'media_url': null,
            'media_type': 'text',
            'caption': caption,
            'background_color': backgroundColor ?? '#000000',
            'text_overlay': textOverlay,
            'text_position': textPosition,
            'expires_at': expiresAt.toIso8601String(),
            'status': 'review', // Start under review for AI moderation
          },
        ];
      } else {
        // Media stories
        payload = mediaItems
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
      }

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

      await _createStoryMentionNotifications(
        stories: stories,
        authorId: userId,
      );

      return stories;
    } catch (e) {
      debugPrint('StoryRepository: failed to create stories - $e');
      return [];
    }
  }

  Future<void> _createStoryMentionNotifications({
    required List<Story> stories,
    required String authorId,
  }) async {
    if (stories.isEmpty) return;

    try {
      for (final story in stories) {
        final content = '${story.caption ?? ''} ${story.textOverlay ?? ''}'
            .trim();
        if (content.isEmpty) continue;

        final mentionedUsernames = _mentionRepository.extractMentions(content);
        if (mentionedUsernames.isEmpty) continue;

        final mentionedUserIds = await _mentionRepository.resolveUsernamesToIds(
          mentionedUsernames,
        );

        for (final userId in mentionedUserIds.toSet()) {
          if (userId == authorId) continue;
          await _notificationRepository.createNotification(
            userId: userId,
            type: 'mention',
            title: 'New Mention',
            body: 'Mentioned you in a story',
            actorId: authorId,
            storyId: story.id,
          );
        }
      }
    } catch (e) {
      debugPrint(
        'StoryRepository: Failed to create story mention notifications - $e',
      );
    }
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$url';
  }

  Future<File?> _downloadStoryMediaToTempFile({
    required String mediaUrl,
    required String mediaType,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final extension = mediaType == 'video' ? 'mp4' : 'jpg';
      final fileName =
          'story_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${tempDir.path}/$fileName';

      final response = await http.get(Uri.parse(_resolveUrl(mediaUrl)));
      if (response.statusCode != 200) return null;

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      debugPrint('StoryRepository: Error downloading story media - $e');
      return null;
    }
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

  /// Run AI detection for a story.
  /// Returns the confidence score on success, or null on failure.
  Future<Map<String, dynamic>?> runAiDetection({
    required String storyId,
    required String authorId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    int retryAttempt = 0,
    bool allowDeferredRetry = true,
  }) async {
    try {
      final trimmedCaption = caption?.trim() ?? '';
      final hasText = trimmedCaption.isNotEmpty;
      final hasMedia =
          (mediaType == 'image' || mediaType == 'video') && mediaUrl.isNotEmpty;

      if (!hasText && !hasMedia) {
        // No content to detect, consider it passed
        await _updateAiScore(storyId: storyId, confidence: 0.0, status: 'pass');
        return {'score': 0.0, 'status': 'pass'};
      }

      AiDetectionResult? result;

      if (hasText && hasMedia && mediaType == 'image') {
        // Mixed detection (caption + image)
        try {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = '${tempDir.path}/$fileName';

          final response = await http.get(Uri.parse(_resolveUrl(mediaUrl)));
          if (response.statusCode == 200) {
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);
            result = await _aiDetectionService.detectMixed(
              trimmedCaption,
              file,
            );
            try {
              await file.delete();
            } catch (e) {
              debugPrint('StoryRepository: Failed to clean up temp file - $e');
            }
          } else {
            // Fallback to text if download fails
            result = await _aiDetectionService.detectText(trimmedCaption);
          }
        } catch (e) {
          debugPrint('StoryRepository: Error in mixed detection - $e');
          result = await _aiDetectionService.detectText(trimmedCaption);
        }
      } else if (hasText && !hasMedia) {
        // Text only
        result = await _aiDetectionService.detectText(trimmedCaption);
      } else if (hasMedia && (mediaType == 'image' || mediaType == 'video')) {
        // Media-only story (image or video)
        final file = await _downloadStoryMediaToTempFile(
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );
        if (file != null) {
          result = await _aiDetectionService.detectImage(file);
          try {
            await file.delete();
          } catch (e) {
            debugPrint('StoryRepository: Failed to clean up temp file - $e');
          }
        }
      } else if (hasText) {
        // Final fallback (e.g. video script)
        result = await _aiDetectionService.detectText(trimmedCaption);
      }

      if (result != null) {
        final bool isAi = result.result.contains('AI');
        final double aiProbability = isAi
            ? result.confidence
            : 100 - result.confidence;

        // Determine status based on AI probability
        final String status;
        if (aiProbability >= 95) {
          status = 'flagged';
        } else if (aiProbability >= 75) {
          status = 'flagged';
        } else if (aiProbability >= 60) {
          status = 'review';
        } else {
          status = 'pass';
        }

        await _updateAiScore(
          storyId: storyId,
          confidence: aiProbability,
          status: status,
          analysisId: result.analysisId,
          aiMetadata: {
            'consensus_strength': result.consensusStrength,
            'rationale': result.rationale,
            'combined_evidence': result.combinedEvidence,
            'classification': result.result,
            'moderation': result.moderation?.toJson(),
            'safety_score': result.safetyScore,
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
            aiModel: result.analysisId,
            aiMetadata: {
              'consensus_strength': result.consensusStrength,
              'rationale': result.rationale,
              'combined_evidence': result.combinedEvidence,
              'classification': result.result,
            },
          );
        }

        return {'score': aiProbability, 'status': status};
      } else {
        // Failed detection: don't leave stories stuck under review.
        await _updateAiScore(storyId: storyId, confidence: 0.0, status: 'pass');
        await _sendAiResultNotification(
          userId: authorId,
          storyId: storyId,
          storyStatus: 'pass',
          aiProbability: 0.0,
        );
        return {'score': 0.0, 'status': 'pass'};
      }
    } catch (e) {
      if (e is TimeoutException) {
        if (retryAttempt < 1) {
          debugPrint(
            'StoryRepository: AI detection timed out for story $storyId, retrying once...',
          );
          await Future.delayed(const Duration(seconds: 2));
          return runAiDetection(
            storyId: storyId,
            authorId: authorId,
            mediaUrl: mediaUrl,
            mediaType: mediaType,
            caption: caption,
            retryAttempt: retryAttempt + 1,
            allowDeferredRetry: allowDeferredRetry,
          );
        }

        debugPrint(
          'StoryRepository: AI detection still timing out for story $storyId; keeping status under review',
        );

        await _updateAiScore(storyId: storyId, confidence: 0.0, status: 'review');
        await _notificationRepository.createNotification(
          userId: authorId,
          type: 'story_review',
          title: 'Story Under Review',
          body:
              'Story analysis is taking longer than expected. It is still under AI review.',
          storyId: storyId,
        );
        if (allowDeferredRetry) {
          unawaited(
            _scheduleDeferredAiRetry(
              storyId: storyId,
              authorId: authorId,
              mediaUrl: mediaUrl,
              mediaType: mediaType,
              caption: caption,
            ),
          );
        }

        return {'score': 0.0, 'status': 'review'};
      }

      debugPrint(
        'StoryRepository: AI detection failed for story $storyId - $e',
      );
      try {
        await _updateAiScore(storyId: storyId, confidence: 0.0, status: 'pass');
        await _sendAiResultNotification(
          userId: authorId,
          storyId: storyId,
          storyStatus: 'pass',
          aiProbability: 0.0,
        );
      } catch (inner) {
        debugPrint(
          'StoryRepository: Failed to apply fallback pass status for story $storyId - $inner',
        );
      }
      return {'score': 0.0, 'status': 'pass'};
    }
  }

  Future<void> _scheduleDeferredAiRetry({
    required String storyId,
    required String authorId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    try {
      debugPrint(
        'StoryRepository: Scheduling deferred AI retry for story $storyId in 45s',
      );
      await Future.delayed(const Duration(seconds: 45));
      await runAiDetection(
        storyId: storyId,
        authorId: authorId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption,
        retryAttempt: 0,
        allowDeferredRetry: false,
      );
    } catch (e) {
      debugPrint(
        'StoryRepository: Deferred AI retry failed for story $storyId - $e',
      );
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
          title = 'Story Published';
          body = 'Your story passed verification and is now live!';
          type = 'story_published';
          break;
        case 'review':
          title = 'Story Under Review';
          body =
              'Your story is being checked for AI. You\'ll be notified soon.';
          type = 'story_review';
          break;
        case 'flagged':
          title = 'Story Not Published';
          body =
              'Your story was flagged as potentially AI-generated (${aiProbability.toStringAsFixed(0)}% confidence).';
          type = 'story_flagged';
          break;
        default:
          return; // Don't send notification for unknown status
      }

      final created = await _notificationRepository.createNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        storyId: storyId,
      );

      if (created) {
        debugPrint(
          'StoryRepository: Sent AI result notification to $userId for story $storyId (status: $storyStatus)',
        );
      } else {
        debugPrint(
          'StoryRepository: AI result notification skipped/failed for story $storyId (status: $storyStatus)',
        );
      }
    } catch (e) {
      debugPrint('StoryRepository: Error sending AI result notification - $e');
    }
  }
}
