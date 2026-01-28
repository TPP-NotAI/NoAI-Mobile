import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'supabase_service.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _supabase = SupabaseService().client;

  /// Fetch all conversations for the current user.
  Future<List<Conversation>> getConversations({
    bool showArchived = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get conversation IDs where the user is a participant
    List<dynamic> participantsResponse = [];
    try {
      var query = _supabase
          .from('conversation_participants')
          .select('conversation_id')
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
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);
      participantsResponse = fallbackQuery as List;
      if (showArchived) return [];
    }

    final conversationIds = participantsResponse
        .map((p) => p['conversation_id'] as String)
        .toList();

    if (conversationIds.isEmpty) return [];

    // Get conversation details and other participants
    final conversationsResponse = await _supabase
        .from('conversations')
        .select('''
          *,
          conversation_participants!inner(
            user_id,
            profiles:user_id(*)
          )
        ''')
        .inFilter('id', conversationIds)
        .order('last_message_at', ascending: false);

    final List<Conversation> conversations = [];

    for (var data in conversationsResponse as List) {
      final convId = data['id'];

      // Fetch last message
      final lastMessageResponse = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastMessageResponse == null) {
        // Skip empty conversations as requested
        continue;
      }

      final lastMessage = Message.fromSupabase(lastMessageResponse);

      // Fetch unread count
      final unreadCountResponse = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', convId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      final unreadCount = (unreadCountResponse as List).length;

      final participantsData = data['conversation_participants'] as List;
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
  Future<void> archiveConversation(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_archived': true})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint(
        'Archive failed: $e. It might be because is_archived column does not exist.',
      );
    }
  }

  /// Unarchive a conversation for the current user.
  Future<void> unarchiveConversation(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_archived': false})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Unarchive failed: $e');
    }
  }

  /// Delete a conversation for the current user (removes participant record).
  Future<void> deleteConversationForUser(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('conversation_participants')
        .delete()
        .eq('conversation_id', conversationId)
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

    // If privacy is 'private', nobody can message them (except maybe logic for mutuals/admins, but keeping simple for now)
    if (visibility == 'private') {
      throw Exception('This user does not accept messages.');
    }

    // If privacy is 'followers', check if current user follows them
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

    // 2. Check if a 1:1 conversation already exists
    // This is a bit tricky in Supabase without a custom RPC,
    // but we can query for conversations where both users are participants.

    // Get all conversation IDs for current user
    final myConvs = await _supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', currentUserId);

    final myConvIds = (myConvs as List)
        .map((c) => c['conversation_id'])
        .toList();

    if (myConvIds.isNotEmpty) {
      // Find if any of these also have the other user
      final commonConvs = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', otherUserId)
          .inFilter('conversation_id', myConvIds);

      if ((commonConvs as List).isNotEmpty) {
        final convId = commonConvs.first['conversation_id'];

        // Fetch the full conversation
        final convData = await _supabase
            .from('conversations')
            .select('''
              *,
              conversation_participants!inner(
                user_id,
                profiles:user_id(*)
              )
            ''')
            .eq('id', convId)
            .single();

        final participants = (convData['conversation_participants'] as List)
            .map((p) {
              return User.fromSupabase(p['profiles'] as Map<String, dynamic>);
            })
            .toList();

        return Conversation.fromSupabase(convData, participants: participants);
      }
    }

    // Create new conversation
    final newConv = await _supabase
        .from('conversations')
        .insert({})
        .select()
        .single();

    final convId = newConv['id'];

    // Add participants
    await _supabase.from('conversation_participants').insert([
      {'conversation_id': convId, 'user_id': currentUserId},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);

    // Already fetched other user above
    final currentUserResponse = await _supabase
        .from('profiles')
        .select()
        .eq('user_id', currentUserId)
        .single();
    final currentUser = User.fromSupabase(currentUserResponse);

    return Conversation.fromSupabase(
      newConv,
      participants: [currentUser, otherUser],
    );
  }

  /// Fetch messages for a conversation.
  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((m) => Message.fromSupabase(m)).toList();
  }

  /// Send a message.
  Future<Message> sendMessage(
    String conversationId,
    String content, {
    String type = 'text',
    String? mediaUrl,
    String? replyToId,
    String? replyContent,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': userId,
          'content': content,
          'message_type': type,
          'media_url': mediaUrl,
          'reply_to_id': replyToId,
          'reply_content': replyContent,
        })
        .select()
        .single();

    // Update conversation's last_message_at
    await _supabase
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    return Message.fromSupabase(response);
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId);
  }

  /// Delete an entire conversation.
  Future<void> deleteConversation(String conversationId) async {
    await _supabase.from('conversations').delete().eq('id', conversationId);
  }

  /// Upload media to Supabase Storage.
  Future<String?> uploadMedia(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final extension = fileName.split('.').last;
      final path = '${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage
          .from('chat_media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );

      return _supabase.storage.from('chat_media').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  /// Stream messages for a conversation.
  Stream<List<Message>> subscribeToMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .map((data) => data.map((m) => Message.fromSupabase(m)).toList());
  }

  /// Mark all messages in a conversation as read for the current user.
  Future<void> markMessagesAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }
}
