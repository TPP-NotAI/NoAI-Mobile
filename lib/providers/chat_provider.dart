import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final _chatService = ChatService();

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
      _conversations = await _chatService.getConversations(
        showArchived: showArchived,
      );
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
        type: type,
        mediaUrl: mediaUrl,
        replyToId: replyToId,
        replyContent: replyContent,
      );

      // Refresh list to show last message
      await loadConversations();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
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
          type: type,
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
    return _chatService.subscribeToMessages(conversationId);
  }

  /// Mark messages as read.
  Future<void> markAsRead(String conversationId) async {
    try {
      await _chatService.markMessagesAsRead(conversationId);

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
}
