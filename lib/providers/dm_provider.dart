import 'package:flutter/material.dart';

import '../models/dm_thread.dart';
import '../models/dm_message.dart';
import '../services/dm_service.dart';

class DmProvider extends ChangeNotifier {
  final _dmService = DmService();

  List<DmThread> _threads = [];
  List<DmThread> get threads => _threads;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Fetch DM threads from DB.
  Future<void> loadThreads() async {
    _isLoading = true;
    notifyListeners();

    try {
      _threads = await _dmService.getThreads();
    } catch (e) {
      debugPrint('Error loading DM threads: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get or create a DM thread with another user.
  Future<DmThread?> startThread(String otherUserId) async {
    try {
      final thread = await _dmService.getOrCreateThread(otherUserId);
      return thread;
    } catch (e) {
      debugPrint('Error starting DM thread: $e');
      return null;
    }
  }

  /// Send a message and refresh the thread list.
  /// Throws on AI block or advertisement detection so the UI can display the error.
  Future<void> sendMessage(
    String threadId,
    String body, {
    String? replyToId,
    String? replyContent,
    Future<bool> Function(double adConfidence, String? adType)? onAdFeeRequired,
  }) async {
    await _dmService.sendMessage(
      threadId,
      body,
      replyToId: replyToId,
      replyContent: replyContent,
      onAdFeeRequired: onAdFeeRequired,
    );
    loadThreads();
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _dmService.deleteMessage(messageId);
    } catch (e) {
      debugPrint('Error deleting DM message: $e');
    }
  }

  /// Delete a thread.
  Future<void> deleteThread(String threadId) async {
    try {
      await _dmService.deleteThread(threadId);
      _threads.removeWhere((t) => t.id == threadId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting DM thread: $e');
    }
  }

  /// Toggle mute on a thread.
  Future<void> toggleMute(String threadId, bool muted) async {
    try {
      await _dmService.toggleMute(threadId, muted);
      await loadThreads();
    } catch (e) {
      debugPrint('Error toggling DM mute: $e');
    }
  }

  /// Subscribe to real-time messages for a thread.
  Stream<List<DmMessage>> getMessageStream(String threadId) {
    return _dmService.subscribeToMessages(threadId);
  }
}
