import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  static const _recentlyReadRetention = Duration(days: 30);
  static const _readCacheKey = 'chat_recently_read';
  static const _deletedMessagesKey = 'chat_locally_deleted';

  final _chatService = ChatService();
  final Map<String, DateTime> _recentlyReadAt = {};
  final Set<String> _locallyDeletedMessageIds = {};
  Future<void>? _cacheInit;
  SharedPreferences? _preferences;
  bool _cacheDirty = false;

  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int get totalUnreadCount =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

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

      // Update local list if not present
      if (!_conversations.any((c) => c.id == conversation.id)) {
        // Note: New conversations might not have messages yet,
        // but startConversation is usually followed by a message.
        // We'll let it be for now.
      }

      return conversation;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      return null;
    }
  }

  /// Send message and refresh list.
  Future<void> sendMessage(
    String conversationId,
    String content, {
    String type = 'text',
    String? mediaUrl,
    String? replyToId,
    String? replyContent,
  }) async {
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
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting conversation for user: $e');
    }
  }

  /// Send a media message.
  Future<void> sendMediaMessage(
    String conversationId,
    String filePath,
    String fileName,
    String type,
  ) async {
    try {
      final mediaUrl = await _chatService.uploadMedia(filePath, fileName);
      if (mediaUrl != null) {
        await _chatService.sendMessage(
          conversationId,
          '[Media]',
          mediaType: type,
          mediaUrl: mediaUrl,
        );
        await loadConversations();
      }
    } catch (e) {
      debugPrint('Error sending media message: $e');
    }
  }

  /// Subscribe to messages for a specific conversation.
  Stream<List<Message>> getMessageStream(String conversationId) {
    return _chatService.subscribeToMessages(conversationId).map((messages) {
      return messages
          .where((m) => !_locallyDeletedMessageIds.contains(m.id))
          .toList();
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
