import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'supabase_service.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/ai_detection_result.dart';
import '../config/supabase_config.dart';
import 'ai_detection_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _supabase = SupabaseService().client;
  final _aiService = AiDetectionService();

  /// Fetch all conversations for the current user.
  Future<List<Conversation>> getConversations({
    bool showArchived = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get thread IDs where the user is a participant
    List<dynamic> participantsResponse = [];
    try {
      var query = _supabase
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', userId);

      if (showArchived) {
        query = query.eq('is_archived', true);
      } else {
        query = query.or('is_archived.eq.false,is_archived.is.null');
      }

      participantsResponse = await query;
    } catch (e) {
      debugPrint('Archived filter failed, falling back: $e');
      final fallbackQuery = await _supabase
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', userId);
      participantsResponse = fallbackQuery as List;
      if (showArchived) return [];
    }

    final threadIds = participantsResponse
        .map((p) => p['thread_id'] as String)
        .toList();

    if (threadIds.isEmpty) return [];

    // Get thread details and other participants, filtering by left_at if needed
    // We only show conversations where the last_message_at is after the participant's left_at (or left_at is null)
    final threadsResponse = await _supabase
        .from('dm_threads')
        .select('''
          *,
          dm_participants!inner(
            user_id,
            left_at,
            profiles:user_id(*)
          )
        ''')
        .inFilter('id', threadIds)
        .order('last_message_at', ascending: false);

    final List<Conversation> conversations = [];

    for (var data in threadsResponse as List) {
      final threadId = data['id'];

      // Fetch last message (not flagged, and only show under_review if user sent it)
      final lastMessagesResponse = await _supabase
          .from('dm_messages')
          .select()
          .eq('thread_id', threadId)
          .neq('ai_score_status', 'flagged')
          .order('created_at', ascending: false)
          .limit(5);

      final lastMessages = (lastMessagesResponse as List)
          .map((m) => Message.fromSupabase(m))
          .toList();

      final lastMessage = lastMessages.isEmpty
          ? null
          : lastMessages.cast<Message?>().firstWhere(
              (m) =>
                  m != null &&
                  (m.aiScoreStatus != 'review' || m.senderId == userId),
              orElse: () => null,
            );

      if (lastMessage == null) {
        // Skip empty conversations as requested
        continue;
      }

      // Get unread count from dm_participants
      final participantData = await _supabase
          .from('dm_participants')
          .select('unread_count')
          .eq('thread_id', threadId)
          .eq('user_id', userId)
          .maybeSingle();

      final unreadCount = participantData?['unread_count'] as int? ?? 0;

      final participantsData = data['dm_participants'] as List;
      final myParticipant = participantsData.firstWhere(
        (p) => p['user_id'] == userId,
      );
      final leftAtStr = myParticipant['left_at'] as String?;

      if (leftAtStr != null) {
        final leftAt = DateTime.parse(leftAtStr);
        if (lastMessage.createdAt.isBefore(leftAt)) {
          // Hide thread if last message is older than when user "deleted" it
          continue;
        }
      }

      final participants = participantsData.map((p) {
        return User.fromSupabase(p['profiles'] as Map<String, dynamic>);
      }).toList();

      conversations.add(
        Conversation.fromSupabase(
          data,
          participants: participants,
          lastMessage: lastMessage,
          unreadCount: unreadCount,
        ),
      );
    }

    return conversations;
  }

  /// Archive a conversation for the current user.
  Future<void> archiveConversation(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('dm_participants')
          .update({'is_archived': true})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Archive failed: $e');
    }
  }

  /// Unarchive a conversation for the current user.
  Future<void> unarchiveConversation(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('dm_participants')
          .update({'is_archived': false})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Unarchive failed: $e');
    }
  }

  /// Delete a conversation for the current user (sets left_at timestamp).
  Future<void> deleteConversationForUser(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('dm_participants')
        .update({'left_at': DateTime.now().toIso8601String()})
        .eq('thread_id', threadId)
        .eq('user_id', userId);
  }

  /// Get or create a conversation with another user.
  /// Respects privacy settings: checks if the target user allows messages from the current user.
  Future<Conversation> getOrCreateConversation(String otherUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // 1. Check privacy settings of the other user
    final otherUserResponse = await _supabase
        .from('profiles')
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
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', otherUserId)
          .maybeSingle();

      if (followResponse == null) {
        throw Exception('This user only accepts messages from followers.');
      }
    }

    // 2. Check if a 1:1 thread already exists
    final myThreads = await _supabase
        .from('dm_participants')
        .select('thread_id')
        .eq('user_id', currentUserId);

    final myThreadIds = (myThreads as List).map((c) => c['thread_id']).toList();

    if (myThreadIds.isNotEmpty) {
      final commonThreads = await _supabase
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', otherUserId)
          .inFilter('thread_id', myThreadIds);

      if ((commonThreads as List).isNotEmpty) {
        final threadId = commonThreads.first['thread_id'];

        final threadData = await _supabase
            .from('dm_threads')
            .select('''
              *,
              dm_participants!inner(
                user_id,
                profiles:user_id(*)
              )
            ''')
            .eq('id', threadId)
            .single();

        final participants = (threadData['dm_participants'] as List).map((p) {
          return User.fromSupabase(p['profiles'] as Map<String, dynamic>);
        }).toList();

        return Conversation.fromSupabase(
          threadData,
          participants: participants,
        );
      }
    }

    // Create new thread
    final newThread = await _supabase
        .from('dm_threads')
        .insert({'created_by': currentUserId})
        .select()
        .single();

    final threadId = newThread['id'];

    // Add participants
    await _supabase.from('dm_participants').insert([
      {'thread_id': threadId, 'user_id': currentUserId},
      {'thread_id': threadId, 'user_id': otherUserId},
    ]);

    final currentUserResponse = await _supabase
        .from('profiles')
        .select()
        .eq('user_id', currentUserId)
        .single();
    final currentUser = User.fromSupabase(currentUserResponse);

    return Conversation.fromSupabase(
      newThread,
      participants: [currentUser, otherUser],
    );
  }

  /// Fetch messages for a conversation.
  Future<List<Message>> getMessages(String threadId, {int limit = 50}) async {
    final response = await _supabase
        .from('dm_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((m) => Message.fromSupabase(m)).toList();
  }

  /// Send a message.
  Future<Message> sendMessage(
    String threadId,
    String content, {
    String? mediaUrl,
    String? mediaType,
    String? replyToId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final insertData = <String, dynamic>{
      'thread_id': threadId,
      'sender_id': userId,
      'body': content,
    };

    if (mediaUrl != null) insertData['media_url'] = mediaUrl;
    if (mediaType != null) insertData['media_type'] = mediaType;
    if (replyToId != null) insertData['reply_to_id'] = replyToId;

    final response = await _supabase
        .from('dm_messages')
        .insert(insertData)
        .select()
        .single();

    final previewContent = Message.stripStoryReferenceFromContent(content);

    // Update thread's last_message_at and preview
    await _supabase
        .from('dm_threads')
        .update({
          'last_message_at': DateTime.now().toIso8601String(),
          'last_message_preview': previewContent.length > 100
              ? '${previewContent.substring(0, 100)}...'
              : previewContent,
        })
        .eq('id', threadId);

    final message = Message.fromSupabase(response);

    // Trigger AI Detection asynchronously
    unawaited(runAiDetection(message));

    return message;
  }

  /// Run AI detection on a message.
  Future<void> runAiDetection(Message message) async {
    try {
      final textContent = message.displayContent;
      final hasText = textContent.isNotEmpty && textContent != '[Media]';
      final hasMedia =
          message.mediaUrl != null &&
          message.mediaUrl!.isNotEmpty &&
          (message.mediaType == 'image' || message.mediaType == 'video');

      if (!hasText && !hasMedia) return;

      AiDetectionResult? result;

      if (hasText && hasMedia && message.mediaType == 'image') {
        // Mixed detection (text + image)
        File? mediaFile = await _downloadMedia(message.mediaUrl!);
        if (mediaFile != null) {
          result = await _aiService.detectMixed(textContent, mediaFile);
          _cleanupFile(mediaFile);
        } else {
          result = await _aiService.detectText(textContent);
        }
      } else if (hasText && !hasMedia) {
        // Text only
        result = await _aiService.detectText(textContent);
      } else if (hasMedia && message.mediaType == 'image') {
        // Image only
        File? mediaFile = await _downloadMedia(message.mediaUrl!);
        if (mediaFile != null) {
          result = await _aiService.detectImage(mediaFile);
          _cleanupFile(mediaFile);
        }
      } else if (hasText) {
        // Text fallback (messages with video captions)
        result = await _aiService.detectText(textContent);
      }

      if (result == null) return;

      final bool isAiResult = result.result.contains('AI');
      final double aiProbability = isAiResult
          ? result.confidence
          : 100 - result.confidence;

      // Update message in DB
      try {
        await _supabase
            .from('dm_messages')
            .update({
              'ai_score': aiProbability,
              'ai_score_status': aiProbability >= 75
                  ? 'flagged'
                  : (aiProbability >= 50 ? 'review' : 'pass'),
              'ai_metadata': {
                'analysis_id': result.analysisId,
                'rationale': result.rationale,
                'combined_evidence': result.combinedEvidence,
                'consensus_strength': result.consensusStrength,
              },
              'verification_session_id': result.analysisId,
            })
            .eq('id', message.id);
      } catch (e) {
        debugPrint('ChatService: Failed to update AI fields in DB - $e');
      }

      // Create moderation case if flagged or review required
      if (aiProbability >= 50) {
        try {
          // Check if a case already exists
          final existing = await _supabase
              .from('moderation_cases')
              .select('id')
              .eq('message_id', message.id)
              .maybeSingle();

          if (existing == null) {
            await _supabase.from('moderation_cases').insert({
              'message_id': message.id,
              'reported_user_id': message.senderId,
              'reason': 'ai_generated',
              'source': 'ai',
              'ai_confidence': aiProbability,
              'status': 'pending',
              'priority': 'normal',
              'description':
                  'Automated AI detection flagged this message with ${aiProbability.toStringAsFixed(1)}% confidence.',
              'ai_metadata': {
                'analysis_id': result.analysisId,
                'rationale': result.rationale,
                'combined_evidence': result.combinedEvidence,
              },
            });
            debugPrint(
              'ChatService: Created moderation case for message ${message.id}',
            );
          }
        } catch (e) {
          debugPrint('ChatService: Failed to create moderation case - $e');
        }
      }
    } catch (e) {
      debugPrint('ChatService: Error in runAiDetection - $e');
    }
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('dm_messages').delete().eq('id', messageId);
  }

  /// Delete an entire conversation.
  Future<void> deleteConversation(String threadId) async {
    await _supabase.from('dm_threads').delete().eq('id', threadId);
  }

  /// Upload media to Supabase Storage.
  Future<String?> uploadMedia(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final extension = fileName.split('.').last;
      final path = '${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage
          .from(SupabaseConfig.chatMediaBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );

      return _supabase.storage
          .from(SupabaseConfig.chatMediaBucket)
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  Stream<List<Message>> subscribeToMessages(String threadId) {
    final currentUserId = _supabase.auth.currentUser?.id;

    // We use asyncMap to fetch the participant's left_at timestamp once
    // and filter messages that were created before the user last "deleted" the chat.
    return _supabase
        .from('dm_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          // Fetch our participant record to check left_at
          final participant = await _supabase
              .from('dm_participants')
              .select('left_at')
              .eq('thread_id', threadId)
              .eq('user_id', currentUserId ?? '')
              .maybeSingle();

          final leftAtStr = participant?['left_at'] as String?;
          final leftAt = leftAtStr != null ? DateTime.parse(leftAtStr) : null;

          final allMessages = data.map((m) => Message.fromSupabase(m)).toList();

          return allMessages.where((m) {
            // Filter by left_at (Hide messages from before the last deletion)
            if (leftAt != null && m.createdAt.isBefore(leftAt)) return false;

            // Hide flagged messages from both players
            if (m.aiScoreStatus == 'flagged') return false;

            // Hide review messages from the recipient
            if (m.aiScoreStatus == 'review' && m.senderId != currentUserId) {
              return false;
            }

            return true;
          }).toList();
        });
  }

  /// Mark all messages in a conversation as read for the current user.
  Future<void> markMessagesAsRead(String threadId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Update the participant's unread count and last_read_at
    await _supabase
        .from('dm_participants')
        .update({
          'unread_count': 0,
          'last_read_at': DateTime.now().toIso8601String(),
        })
        .eq('thread_id', threadId)
        .eq('user_id', userId);
  }

  /// Helper to download media from URL to a temporary file.
  Future<File?> _downloadMedia(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'msg_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('ChatService: Error downloading media - $e');
    }
    return null;
  }

  void _cleanupFile(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('ChatService: Error cleaning up file - $e');
    }
  }
}
