import 'dart:async';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';
import '../config/supabase_config.dart';
import '../models/dm_thread.dart';
import '../models/dm_message.dart';
import '../models/user.dart';
import '../repositories/notification_repository.dart';
import 'ai_detection_service.dart';

class DmService {
  static final DmService _instance = DmService._internal();
  factory DmService() => _instance;
  DmService._internal();

  final _supabase = SupabaseService().client;
  final _aiService = AiDetectionService();
  final NotificationRepository _notificationRepository = NotificationRepository();

  /// Fetch all DM threads for the current user.
  Future<List<DmThread>> getThreads() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get thread IDs where the user is a participant
    final participantsResponse = await _supabase
        .from(SupabaseConfig.dmParticipantsTable)
        .select('thread_id')
        .eq('user_id', userId);

    final threadIds = (participantsResponse as List)
        .map((p) => p['thread_id'] as String)
        .toList();

    if (threadIds.isEmpty) return [];

    // Get thread details with participants
    final threadsResponse = await _supabase
        .from(SupabaseConfig.dmThreadsTable)
        .select('''
          *,
          ${SupabaseConfig.dmParticipantsTable}!inner(
            user_id,
            muted,
            profiles:user_id(*)
          )
        ''')
        .inFilter('id', threadIds)
        .order('last_message_at', ascending: false);

    final List<DmThread> threads = [];

    for (var data in threadsResponse as List) {
      final threadId = data['id'] as String;

      // Fetch last message
      final lastMessageResponse = await _supabase
          .from(SupabaseConfig.dmMessagesTable)
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastMessageResponse == null) continue; // Skip empty threads

      final lastMessage = DmMessage.fromSupabase(lastMessageResponse);

      final participantsData = data[SupabaseConfig.dmParticipantsTable] as List;
      final participants = participantsData.map((p) {
        return User.fromSupabase(p['profiles'] as Map<String, dynamic>);
      }).toList();

      threads.add(
        DmThread.fromSupabase(
          data,
          participants: participants,
          lastMessage: lastMessage,
        ),
      );
    }

    return threads;
  }

  /// Get or create a DM thread with another user.
  /// Respects the target user's messagesVisibility privacy setting.
  Future<DmThread> getOrCreateThread(String otherUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // 1. Check privacy settings
    final otherUserResponse = await _supabase
        .from(SupabaseConfig.profilesTable)
        .select()
        .eq('user_id', otherUserId)
        .single();

    final otherUser = User.fromSupabase(otherUserResponse);
    final visibility = otherUser.messagesVisibility ?? 'everyone';

    if (visibility == 'private') {
      throw Exception('This user does not accept messages.');
    }

    if (visibility == 'followers') {
      final followResponse = await _supabase
          .from(SupabaseConfig.followsTable)
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', otherUserId)
          .maybeSingle();

      if (followResponse == null) {
        throw Exception('This user only accepts messages from followers.');
      }
    }

    // 2. Check for existing thread between the two users
    final myThreads = await _supabase
        .from(SupabaseConfig.dmParticipantsTable)
        .select('thread_id')
        .eq('user_id', currentUserId);

    final myThreadIds = (myThreads as List).map((t) => t['thread_id']).toList();

    if (myThreadIds.isNotEmpty) {
      final commonThreads = await _supabase
          .from(SupabaseConfig.dmParticipantsTable)
          .select('thread_id')
          .eq('user_id', otherUserId)
          .inFilter('thread_id', myThreadIds);

      if ((commonThreads as List).isNotEmpty) {
        final threadId = commonThreads.first['thread_id'] as String;

        final threadData = await _supabase
            .from(SupabaseConfig.dmThreadsTable)
            .select('''
              *,
              ${SupabaseConfig.dmParticipantsTable}!inner(
                user_id,
                muted,
                profiles:user_id(*)
              )
            ''')
            .eq('id', threadId)
            .single();

        final participants =
            (threadData[SupabaseConfig.dmParticipantsTable] as List)
                .map(
                  (p) =>
                      User.fromSupabase(p['profiles'] as Map<String, dynamic>),
                )
                .toList();

        return DmThread.fromSupabase(threadData, participants: participants);
      }
    }

    // 3. Create new thread
    final newThread = await _supabase
        .from(SupabaseConfig.dmThreadsTable)
        .insert({'created_by': currentUserId})
        .select()
        .single();

    final threadId = newThread['id'] as String;

    // Add participants
    await _supabase.from(SupabaseConfig.dmParticipantsTable).insert([
      {'thread_id': threadId, 'user_id': currentUserId},
      {'thread_id': threadId, 'user_id': otherUserId},
    ]);

    final currentUserResponse = await _supabase
        .from(SupabaseConfig.profilesTable)
        .select()
        .eq('user_id', currentUserId)
        .single();
    final currentUser = User.fromSupabase(currentUserResponse);

    return DmThread.fromSupabase(
      newThread,
      participants: [currentUser, otherUser],
    );
  }

  static const double _aiReviewThreshold = 50;
  static const double _aiFlagThreshold = 75;

  /// Send a message in a DM thread.
  /// Runs AI detection pre-check before inserting; blocks flagged content.
  Future<DmMessage> sendMessage(
    String threadId,
    String body, {
    String? replyToId,
    String? replyContent,
    Future<bool> Function(double adConfidence, String? adType)? onAdFeeRequired,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final text = body.trim();

    // Run AI detection before inserting the message
    final precheck = await _runAiPrecheckText(text);

    if (precheck == null) {
      throw Exception(
        'Message blocked: AI verification did not complete. Please try again.',
      );
    }

    if (precheck.aiScoreStatus == 'flagged') {
      throw Exception(
        'Message blocked: content detected as likely AI-generated.',
      );
    }

    bool adFeePaid = false;
    if (precheck.isAdvertisement) {
      if (precheck.requiresPayment) {
        final adMeta = precheck.aiMetadata['advertisement'];
        final adConfidence =
            adMeta is Map ? (adMeta['confidence'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final adType = adMeta is Map ? adMeta['type'] as String? : null;
        adFeePaid =
            onAdFeeRequired != null &&
            await onAdFeeRequired(adConfidence, adType);
        if (!adFeePaid) {
          throw Exception(
            'Advertisement detected. Message was not sent because the ad fee was not paid.',
          );
        }
      }
      if (!precheck.requiresPayment) {
        throw Exception(
          'Message blocked: advertisement content is not allowed in chats.',
        );
      }
    }

    final insertData = <String, dynamic>{
      'thread_id': threadId,
      'sender_id': userId,
      'body': body,
      'ai_score': precheck.aiScore,
      'ai_score_status': precheck.aiScoreStatus,
      'ai_metadata': precheck.aiMetadata,
      'verification_session_id': precheck.analysisId,
      if (replyToId != null) 'reply_to_id': replyToId,
    };

    final response = await _supabase
        .from(SupabaseConfig.dmMessagesTable)
        .insert(insertData)
        .select()
        .single();

    // Update thread's last_message_at
    await _supabase
        .from(SupabaseConfig.dmThreadsTable)
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', threadId);

    final dmMessage = DmMessage.fromSupabase(response);

    // Create moderation case if score warrants review
    await _createModerationCaseIfNeeded(
      messageId: dmMessage.id,
      senderId: dmMessage.senderId,
      aiScore: precheck.aiScore,
      aiMetadata: precheck.aiMetadata,
    );

    // Notify thread recipients on normal pass, or when advert fee was paid
    // (advert messages go only to the conversation recipient, not broadcast to all)
    if (precheck.aiScoreStatus.toLowerCase() == 'pass' || adFeePaid) {
      await _notifyThreadRecipients(
        threadId: threadId,
        senderId: userId,
        previewContent: text,
      );
    }

    return dmMessage;
  }

  Future<void> _notifyThreadRecipients({
    required String threadId,
    required String senderId,
    required String previewContent,
  }) async {
    try {
      final participantRows = await _supabase
          .from(SupabaseConfig.dmParticipantsTable)
          .select('user_id')
          .eq('thread_id', threadId)
          .neq('user_id', senderId);

      final recipients = (participantRows as List<dynamic>)
          .map((e) => e['user_id'] as String?)
          .whereType<String>()
          .toSet();
      if (recipients.isEmpty) return;

      final senderProfile = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('username, display_name')
          .eq('user_id', senderId)
          .maybeSingle();
      final senderName =
          (senderProfile?['display_name'] as String?)?.trim().isNotEmpty == true
          ? (senderProfile!['display_name'] as String).trim()
          : ((senderProfile?['username'] as String?) ?? 'Someone');

      final body = previewContent.trim().isEmpty
          ? 'You received a new message.'
          : (previewContent.length > 120
              ? '${previewContent.substring(0, 120)}...'
              : previewContent);

      for (final recipientId in recipients) {
        await _notificationRepository.createNotification(
          userId: recipientId,
          type: 'chat',
          title: senderName,
          body: body,
          actorId: null,
        );
      }
    } catch (e) {
      debugPrint('DmService: Failed to create message notification - $e');
    }
  }

  Future<_DmPrecheckResult?> _runAiPrecheckText(String text) async {
    try {
      if (text.isEmpty) return null;
      final result = await _aiService.detectFull(
        content: text,
        models: 'gpt-5.2,o3',
      );
      if (result == null) return null;

      final normalizedResult = result.result.trim().toUpperCase();
      final isAiResult =
          normalizedResult == 'AI-GENERATED' ||
          normalizedResult == 'LIKELY AI-GENERATED';
      final labelConfidence = result.confidence.clamp(0, 100);
      final aiScore = isAiResult
          ? labelConfidence.toDouble()
          : (100 - labelConfidence).toDouble();
      final aiScoreStatus = _resolveAiScoreStatus(aiScore);
      final aiMetadata = <String, dynamic>{
        'analysis_id': result.analysisId,
        'rationale': result.rationale,
        'combined_evidence': result.combinedEvidence,
        'consensus_strength': result.consensusStrength,
        'moderation': result.moderation?.toJson(),
        'safety_score': result.safetyScore,
        if (result.advertisement != null)
          'advertisement': result.advertisement!.toJson(),
      };
      final ad = result.advertisement;
      final isAd = ad != null && ad.detected;
      final adRequiresPayment =
          isAd &&
          (ad.requiresPayment ||
              ad.action == 'require_payment' ||
              result.policyRequiresPayment);

      return _DmPrecheckResult(
        aiScore: aiScore,
        aiScoreStatus: aiScoreStatus,
        aiMetadata: aiMetadata,
        analysisId: result.analysisId,
        isAdvertisement: isAd,
        requiresPayment: adRequiresPayment,
      );
    } catch (e) {
      debugPrint('DmService: Pre-send AI detection failed - $e');
      return null;
    }
  }

  String _resolveAiScoreStatus(double aiScore) {
    if (aiScore >= _aiFlagThreshold) return 'flagged';
    if (aiScore >= _aiReviewThreshold) return 'review';
    return 'pass';
  }

  Future<void> _createModerationCaseIfNeeded({
    required String messageId,
    required String senderId,
    required double aiScore,
    required Map<String, dynamic> aiMetadata,
  }) async {
    if (aiScore < _aiReviewThreshold) return;
    try {
      final existing = await _supabase
          .from('moderation_cases')
          .select('id')
          .eq('message_id', messageId)
          .maybeSingle();

      if (existing != null) return;

      await _supabase.from('moderation_cases').insert({
        'message_id': messageId,
        'reported_user_id': senderId,
        'reason': 'ai_generated',
        'source': 'ai',
        'ai_confidence': aiScore,
        'status': 'pending',
        'priority': 'normal',
        'description':
            'Automated AI detection flagged this DM with ${aiScore.toStringAsFixed(1)}% confidence.',
        'ai_metadata': aiMetadata,
      });
      debugPrint('DmService: Created moderation case for message $messageId');
    } catch (e) {
      debugPrint('DmService: Failed to create moderation case - $e');
    }
  }

  /// Fetch messages for a DM thread.
  Future<List<DmMessage>> getMessages(String threadId, {int limit = 50}) async {
    final response = await _supabase
        .from(SupabaseConfig.dmMessagesTable)
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((m) => DmMessage.fromSupabase(m)).toList();
  }

  /// Stream messages for a DM thread (real-time).
  /// Filters out flagged messages entirely; review messages are only visible
  /// to the sender.
  Stream<List<DmMessage>> subscribeToMessages(String threadId) {
    final currentUserId = _supabase.auth.currentUser?.id;
    return _supabase
        .from(SupabaseConfig.dmMessagesTable)
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .map((data) {
          return data
              .map((m) => DmMessage.fromSupabase(m))
              .where((m) {
                if (m.aiScoreStatus == 'flagged') return false;
                if (m.aiScoreStatus == 'review' &&
                    m.senderId != currentUserId) {
                  return false;
                }
                return true;
              })
              .toList();
        });
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _supabase
        .from(SupabaseConfig.dmMessagesTable)
        .delete()
        .eq('id', messageId);
  }

  /// Delete a thread and all its data.
  Future<void> deleteThread(String threadId) async {
    await _supabase
        .from(SupabaseConfig.dmThreadsTable)
        .delete()
        .eq('id', threadId);
  }

  /// Toggle mute for the current user in a thread.
  Future<void> toggleMute(String threadId, bool muted) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from(SupabaseConfig.dmParticipantsTable)
        .update({'muted': muted})
        .eq('thread_id', threadId)
        .eq('user_id', userId);
  }

  /// Check if current user has muted a thread.
  Future<bool> isMuted(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from(SupabaseConfig.dmParticipantsTable)
        .select('muted')
        .eq('thread_id', threadId)
        .eq('user_id', userId)
        .maybeSingle();

    return response?['muted'] as bool? ?? false;
  }
}

class _DmPrecheckResult {
  final double aiScore;
  final String aiScoreStatus;
  final Map<String, dynamic> aiMetadata;
  final String analysisId;
  final bool isAdvertisement;
  final bool requiresPayment;

  const _DmPrecheckResult({
    required this.aiScore,
    required this.aiScoreStatus,
    required this.aiMetadata,
    required this.analysisId,
    this.isAdvertisement = false,
    this.requiresPayment = false,
  });
}
