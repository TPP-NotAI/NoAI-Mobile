import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/push_notification_service.dart';
import '../services/supabase_service.dart';

class ChatProvider extends ChangeNotifier {
  static const _recentlyReadRetention = Duration(days: 30);
  static const _readCacheKey = 'chat_recently_read';
  static const _deletedMessagesKey = 'chat_locally_deleted';

  final _chatService = ChatService();
  final _supabase = SupabaseService().client;
  final Map<String, DateTime> _recentlyReadAt = {};
  final Set<String> _locallyDeletedMessageIds = {};
  // Pending messages keyed by conversationId for optimistic UI
  final Map<String, List<Message>> _pendingMessages = {};
  Future<void>? _cacheInit;
  SharedPreferences? _preferences;
  bool _cacheDirty = false;
  String? _currentUserId;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _threadsChannel;

  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  int get totalUnreadCount =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  /// Start listening for real-time chat updates
  void startListening(String userId) {
    if (_currentUserId == userId && _messagesChannel != null) {
      return; // Already listening for this user
    }

    stopListening();
    _currentUserId = userId;

    // Listen for new messages in any thread the user participates in
    _messagesChannel = _supabase
        .channel('chat:messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_messages',
          callback: (payload) {
            debugPrint('ChatProvider: New message received via real-time');
            _handleNewMessage(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'dm_messages',
          callback: (payload) {
            debugPrint('ChatProvider: Message updated via real-time');
            // Message was updated (e.g., AI moderation status changed)
            notifyListeners();
          },
        )
        .subscribe();

    // Listen for thread updates (last_message_at changes) and participant changes
    _threadsChannel = _supabase
        .channel('chat:threads:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'dm_threads',
          callback: (payload) {
            debugPrint('ChatProvider: Thread updated via real-time');
            _handleThreadUpdate(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('ChatProvider: New conversation detected');
            // New conversation - refresh the list
            loadConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'dm_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('ChatProvider: Participant updated (unread count sync)');
            // Unread count changed (possibly from another device) - refresh
            _handleParticipantUpdate(payload.newRecord);
          },
        )
        .subscribe();

    debugPrint('ChatProvider: Started listening for user=$userId');
  }

  /// Stop listening for real-time updates
  void stopListening() {
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    if (_threadsChannel != null) {
      _supabase.removeChannel(_threadsChannel!);
      _threadsChannel = null;
    }
    _currentUserId = null;
  }

  /// Handle incoming new message from real-time
  void _handleNewMessage(Map<String, dynamic> messageData) {
    final threadId = messageData['thread_id'] as String?;
    final senderId = messageData['sender_id'] as String?;
    final aiScoreStatus = messageData['ai_score_status'] as String?;

    if (threadId == null) return;
    final isFromOther = senderId != _currentUserId;

    // Never surface flagged messages, and keep review messages sender-only.
    if (aiScoreStatus == 'flagged') return;
    if (aiScoreStatus == 'review' && isFromOther) return;

    // Find the conversation
    final index = _conversations.indexWhere((c) => c.id == threadId);

    if (index != -1) {
      final conversation = _conversations[index];
      final newMessage = Message.fromSupabase(messageData);

      // Update the conversation with new message info
      final updatedConversation = conversation.copyWith(
        lastMessage: newMessage,
        lastMessageAt: newMessage.createdAt,
        // Increment unread if message is from someone else
        unreadCount: isFromOther
            ? conversation.unreadCount + 1
            : conversation.unreadCount,
      );

      // Move conversation to top of list
      _conversations.removeAt(index);
      _conversations.insert(0, updatedConversation);
      notifyListeners();

      // Show local notification for incoming messages
      if (isFromOther) {
        final sender = conversation.participants.firstWhere(
          (u) => u.id == senderId,
          orElse: () => conversation.otherParticipant(_currentUserId ?? ''),
        );
        final senderName = sender.displayName.isNotEmpty
            ? sender.displayName
            : sender.username;
        final body = newMessage.mediaType != null
            ? '📎 ${newMessage.displayContent}'
            : newMessage.displayContent;
        PushNotificationService().showLocalNotification(
          title: senderName,
          body: body.isNotEmpty ? body : 'Sent you a message',
          type: 'message',
          data: {'type': 'message', 'thread_id': threadId},
        );
      }
    } else {
      // New conversation we don't have yet - refresh the list
      loadConversations();
    }
  }

  /// Handle thread update from real-time
  void _handleThreadUpdate(Map<String, dynamic> threadData) {
    final threadId = threadData['id'] as String?;
    if (threadId == null) return;

    final index = _conversations.indexWhere((c) => c.id == threadId);
    if (index != -1) {
      // Refresh to get updated data
      loadConversations();
    }
  }

  /// Handle participant update from real-time (unread count sync)
  void _handleParticipantUpdate(Map<String, dynamic> participantData) {
    final threadId = participantData['thread_id'] as String?;
    final unreadCount = participantData['unread_count'] as int? ?? 0;

    if (threadId == null) return;

    final index = _conversations.indexWhere((c) => c.id == threadId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        unreadCount: unreadCount,
      );
      notifyListeners();
    }
  }

  /// Clear all chat data and stop listening (called on logout)
  void clear() {
    stopListening();
    _conversations = [];
    _recentlyReadAt.clear();
    _locallyDeletedMessageIds.clear();
    notifyListeners();
  }

  /// Fetch conversations from DB.
  Future<void> loadConversations({bool showArchived = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _ensureCacheInitialized();
      final now = DateTime.now();
      _purgeStaleRecentlyRead(now);
      final fetched = await _chatService.getConversations(
        showArchived: showArchived,
      );
      final adjusted = <Conversation>[];
      for (final conversation in fetched) {
        adjusted.add(_applyRecentReadOverride(conversation));
      }
      _conversations = adjusted;
      await _persistCacheIfDirty();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get or create a conversation with another user.
  Future<Conversation?> startConversation(String otherUserId) async {
    try {
      final conversation = await _chatService.getOrCreateConversation(
        otherUserId,
      );
      _error = null;

      // Update local list if not present
      if (!_conversations.any((c) => c.id == conversation.id)) {
        // Note: New conversations might not have messages yet,
        // but startConversation is usually followed by a message.
        // We'll let it be for now.
      }

      return conversation;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      _error = e.toString().replaceFirst('Exception: ', '').trim();
      return null;
    }
  }

  /// Send message with optimistic UI — appends a pending message immediately,
  /// then removes it once the server stream confirms delivery.
  Future<void> sendMessage(
    String conversationId,
    String content, {
    String type = 'text',
    String? mediaUrl,
    String? replyToId,
    String? replyContent,
  }) async {
    _error = null;
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pending = Message(
      id: pendingId,
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      content: content,
      mediaUrl: mediaUrl,
      mediaType: type != 'text' ? type : null,
      replyToId: replyToId,
      status: 'sending',
      createdAt: DateTime.now(),
    );

    _pendingMessages.putIfAbsent(conversationId, () => []).add(pending);
    notifyListeners();

    try {
      await _chatService.sendMessage(
        conversationId,
        content,
        mediaUrl: mediaUrl,
        mediaType: type != 'text' ? type : null,
        replyToId: replyToId,
      );
      // Refresh list to show last message
      await loadConversations();
    } catch (e) {
      debugPrint('Error sending message: $e');
      _error = e.toString().replaceFirst('Exception: ', '').trim();
      rethrow;
    } finally {
      _pendingMessages[conversationId]?.removeWhere((m) => m.id == pendingId);
      notifyListeners();
    }
  }

  Future<void> deleteMessageForMe(String messageId) async {
    _locallyDeletedMessageIds.add(messageId);
    _noteCacheDirty();
    await _persistCacheIfDirty();
    notifyListeners();
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
      // Also add to local deleted just in case it takes a moment to sync
      _locallyDeletedMessageIds.add(messageId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _chatService.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  Future<void> archiveConversation(String conversationId) async {
    try {
      await _chatService.archiveConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error archiving conversation: $e');
    }
  }

  Future<void> unarchiveConversation(String conversationId) async {
    try {
      await _chatService.unarchiveConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error unarchiving conversation: $e');
    }
  }

  Future<void> deleteConversationForUser(String conversationId) async {
    try {
      await _chatService.deleteConversationForUser(conversationId);
      _chatService.invalidateLeftAtCache(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting conversation for user: $e');
    }
  }

  /// Send a media message with optimistic pending bubble shown during upload.
  Future<bool> sendMediaMessage(
    String conversationId,
    String filePath,
    String fileName,
    String type,
  ) async {
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final content = _resolveMediaContent(type, fileName);
    final pending = Message(
      id: pendingId,
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      content: content,
      mediaType: type,
      status: 'sending',
      createdAt: DateTime.now(),
    );

    _pendingMessages.putIfAbsent(conversationId, () => []).add(pending);
    notifyListeners();

    try {
      final mediaUrl = await _chatService.uploadMedia(filePath, fileName);
      if (mediaUrl != null) {
        await _chatService.sendMessage(
          conversationId,
          content,
          mediaType: type,
          mediaUrl: mediaUrl,
          localMediaPath: filePath,
        );
        await loadConversations();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending media message: $e');
      _error = e.toString().replaceFirst('Exception: ', '').trim();
      notifyListeners();
      rethrow;
    } finally {
      _pendingMessages[conversationId]?.removeWhere((m) => m.id == pendingId);
      notifyListeners();
    }
  }

  String _resolveMediaContent(String type, String fileName) {
    switch (type.toLowerCase()) {
      case 'audio':
        return 'Voice message';
      case 'document':
        return 'Document: $fileName';
      case 'contact':
        return fileName;
      case 'image':
      case 'video':
      default:
        return '[Media]';
    }
  }

  /// Subscribe to messages for a specific conversation.
  /// Merges any pending (optimistic) messages at the front of the list.
  Stream<List<Message>> getMessageStream(String conversationId) {
    return _chatService.subscribeToMessages(conversationId).map((messages) {
      final confirmed = messages
          .where((m) => !_locallyDeletedMessageIds.contains(m.id))
          .toList();

      // Append pending messages that haven't been confirmed yet
      final pending = _pendingMessages[conversationId] ?? [];
      final pendingUnconfirmed = pending.where((p) {
        // Drop a pending message only when a confirmed message with the same
        // content+sender arrived at or after the pending was created.
        // Using createdAt prevents premature dedup of two identical messages.
        return !confirmed.any(
          (c) =>
              c.content == p.content &&
              c.senderId == p.senderId &&
              !c.createdAt.isBefore(p.createdAt),
        );
      }).toList();

      // confirmed is newest-first (reverse:true list), pending goes at front
      return [...pendingUnconfirmed, ...confirmed];
    });
  }

  /// Mark messages as read.
  Future<void> markAsRead(String conversationId) async {
    await _ensureCacheInitialized();

    try {
      await _chatService.markMessagesAsRead(conversationId);
      await _recordRecentRead(conversationId);

      // Update local unread count
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _recordRecentRead(String conversationId) async {
    _purgeStaleRecentlyRead();
    _recentlyReadAt[conversationId] = DateTime.now();
    _noteCacheDirty();
    await _persistCacheIfDirty();
  }

  void _purgeStaleRecentlyRead([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final stale = _recentlyReadAt.entries
        .where(
          (entry) =>
              reference.difference(entry.value) >= _recentlyReadRetention,
        )
        .map((entry) => entry.key)
        .toList();

    if (stale.isEmpty) return;

    for (final key in stale) {
      _recentlyReadAt.remove(key);
    }
    _noteCacheDirty();
  }

  Conversation _applyRecentReadOverride(Conversation conversation) {
    final readAt = _recentlyReadAt[conversation.id];
    if (readAt == null) {
      return conversation;
    }

    if (conversation.unreadCount == 0 ||
        conversation.lastMessageAt.isAfter(readAt)) {
      _recentlyReadAt.remove(conversation.id);
      _noteCacheDirty();
      return conversation;
    }

    return conversation.copyWith(unreadCount: 0);
  }

  Future<void> _ensureCacheInitialized() {
    return _cacheInit ??= _initCache();
  }

  Future<void> _initCache() async {
    _preferences = await SharedPreferences.getInstance();

    // Init Read Cache
    final cachedRead = _preferences?.getString(_readCacheKey);
    if (cachedRead != null) {
      final decoded = jsonDecode(cachedRead) as Map<String, dynamic>;
      _recentlyReadAt.clear();
      decoded.forEach((key, value) {
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) {
            _recentlyReadAt[key] = parsed;
          }
        }
      });
    }

    // Init Deleted Messages Cache
    final cachedDeleted = _preferences?.getStringList(_deletedMessagesKey);
    if (cachedDeleted != null) {
      _locallyDeletedMessageIds.clear();
      _locallyDeletedMessageIds.addAll(cachedDeleted);
    }

    _purgeStaleRecentlyRead();
    await _persistCacheIfDirty();
  }

  void _noteCacheDirty() {
    _cacheDirty = true;
  }

  Future<void> _persistCacheIfDirty() async {
    if (!_cacheDirty || _preferences == null) return;

    // Save Read Cache
    final readPayload = jsonEncode(
      _recentlyReadAt.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    );
    await _preferences!.setString(_readCacheKey, readPayload);

    // Save Deleted Messages Cache
    await _preferences!.setStringList(
      _deletedMessagesKey,
      _locallyDeletedMessageIds.toList(),
    );

    _cacheDirty = false;
  }
}
