import 'dart:async';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';
import '../config/supabase_config.dart';
import '../models/dm_thread.dart';
import '../models/dm_message.dart';
import '../models/user.dart';
import '../models/ai_detection_result.dart';
import 'ai_detection_service.dart';

class DmService {
  static final DmService _instance = DmService._internal();
  factory DmService() => _instance;
  DmService._internal();

  final _supabase = SupabaseService().client;
  final _aiService = AiDetectionService();

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

  /// Send a message in a DM thread.
  Future<DmMessage> sendMessage(String threadId, String body) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from(SupabaseConfig.dmMessagesTable)
        .insert({'thread_id': threadId, 'sender_id': userId, 'body': body})
        .select()
        .single();

    // Update thread's last_message_at
    await _supabase
        .from(SupabaseConfig.dmThreadsTable)
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', threadId);

    final dmMessage = DmMessage.fromSupabase(response);

    // Trigger AI Detection asynchronously
    unawaited(runAiDetection(dmMessage));

    return dmMessage;
  }

  /// Run AI detection on a DM message.
  Future<void> runAiDetection(DmMessage message) async {
    try {
      final result = await _aiService.detectText(message.body);
      if (result == null) return;

      final bool isAiResult = result.result.contains('AI');

      final double aiProbability = isAiResult
          ? result.confidence
          : 100 - result.confidence;

      // Update message in DB (assuming columns exist, or fail silently if not)
      try {
        await _supabase
            .from(SupabaseConfig.dmMessagesTable)
            .update({
              'ai_score': aiProbability,
              'status': aiProbability >= 50 ? 'flagged' : 'sent',
            })
            .eq('id', message.id);
      } catch (e) {
        debugPrint('DmService: Failed to update AI fields in DB - $e');
      }

      // Create moderation case if flagged
      if (aiProbability >= 75) {
        await _supabase.from('moderation_cases').insert({
          'message_id': message.id,
          'user_id': message.senderId,
          'violation_type': 'ai_generation',
          'ai_confidence': aiProbability,
          'status': 'pending',
          'ai_metadata': {
            'analysis_id': result.analysisId,
            'rationale': result.rationale,
            'combined_evidence': result.combinedEvidence,
          },
        });
      }
    } catch (e) {
      debugPrint('DmService: Error in runAiDetection - $e');
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
  Stream<List<DmMessage>> subscribeToMessages(String threadId) {
    return _supabase
        .from(SupabaseConfig.dmMessagesTable)
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .map((data) => data.map((m) => DmMessage.fromSupabase(m)).toList());
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
