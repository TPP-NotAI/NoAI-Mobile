import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../models/notification_settings.dart';
import '../repositories/notification_repository.dart';
import '../services/supabase_service.dart';
import '../services/push_notification_service.dart';
import '../config/supabase_config.dart';
import '../config/global_keys.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repository = NotificationRepository();
  final _client = SupabaseService().client;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  NotificationSettings? _settings;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _supportMessageChannel;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  NotificationSettings? get settings => _settings;

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  /// Start listening for real-time notifications for a user
  void startListening(String userId) {
    stopListening();

    _notificationChannel = _client
        .channel('public:notifications:user=$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            debugPrint(
              'NotificationProvider: New notification received via real-time',
            );
            // When a new notification arrives, it won't have the joined profiles/posts.
            // We could either fetch just that one notification or just refresh the list.
            // Refreshing the list is safer to get the joins.
            await refreshNotifications(userId);

            // Show local push notification with sound
            final newRecord = payload.newRecord;
            final title = newRecord['title'] as String? ?? 'ROOVERSE';
            final body = newRecord['body'] as String? ?? 'You have a new notification';
            final type = newRecord['type'] as String? ?? 'social';

            await PushNotificationService().showLocalNotification(
              title: title,
              body: body,
              type: type,
              data: {
                'notification_id': newRecord['id'],
                'type': type,
                'title': title,
                'body': body,
                'ticket_id': newRecord['ticket_id'],
                'post_id': newRecord['post_id'],
                'actor_id': newRecord['actor_id'],
              },
            );

            _showInAppNotificationSnackBar(
              type: type,
              title: title,
              body: body,
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            debugPrint(
              'NotificationProvider: Notification updated via real-time',
            );
            // Notification was updated (e.g., marked as read on another device)
            await refreshNotifications(userId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConfig.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            debugPrint(
              'NotificationProvider: Notification deleted via real-time',
            );
            // Notification was deleted
            await refreshNotifications(userId);
          },
        )
        .subscribe();

    // Listen for support ticket replies from staff/admin and show a local notification.
    // This is app-side realtime, so it works while the app is running.
    _supportMessageChannel = _client
        .channel('public:support-ticket-messages:user=$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.supportTicketMessagesTable,
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final isStaff = newRecord['is_staff'] as bool? ?? false;
            if (!isStaff) return;

            final ticketId = newRecord['ticket_id'] as String?;
            final messageText = (newRecord['message'] as String? ?? '').trim();
            if (ticketId == null || messageText.isEmpty) return;

            try {
              final ticketRow = await _client
                  .from(SupabaseConfig.supportTicketsTable)
                  .select('id, user_id, subject')
                  .eq('id', ticketId)
                  .maybeSingle();

              if (ticketRow == null) return;
              if ((ticketRow['user_id'] as String?) != userId) return;

              final subject = (ticketRow['subject'] as String?)?.trim();
              final title = (subject != null && subject.isNotEmpty)
                  ? 'Support: $subject'
                  : 'Support Team';
              final body = messageText.length > 180
                  ? '${messageText.substring(0, 180)}...'
                  : messageText;
              final senderId = newRecord['sender_id'] as String?;

              // Fallback: ensure a notification row exists so it appears in the
              // in-app Notifications screen (backend should ideally do this).
              final notificationRowAvailable = await _ensureSupportNotificationRow(
                userId: userId,
                ticketId: ticketId,
                title: title,
                body: body,
                actorId: senderId,
              );

              // Avoid duplicate local pushes/snackbars when a notification row
              // exists (the notifications realtime listener will handle UI).
              if (!notificationRowAvailable) {
                await PushNotificationService().showLocalNotification(
                  title: title,
                  body: body,
                  type: 'support_chat',
                  data: {
                    'type': 'support_chat',
                    'title': title,
                    'body': body,
                    'ticket_id': ticketId,
                  },
                );

                _showInAppNotificationSnackBar(
                  type: 'support_chat',
                  title: title,
                  body: body,
                );
              }
            } catch (e) {
              debugPrint(
                'NotificationProvider: Failed support message notification - $e',
              );
            }
          },
        )
        .subscribe();

    debugPrint(
      'NotificationProvider: Listening for notifications for user=$userId',
    );
  }

  bool _isAiStatusType(String type, String title) {
    return type.startsWith('post_') ||
        type.startsWith('comment_') ||
        type.startsWith('story_') ||
        (type == 'mention' &&
            (title.startsWith('Post ') ||
                title.startsWith('Comment ') ||
                title.startsWith('Story ')));
  }

  void _showInAppNotificationSnackBar({
    required String type,
    required String title,
    required String body,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    Color? backgroundColor;
    if (_isAiStatusType(type, title)) {
      final lowerTitle = title.toLowerCase();
      final lowerBody = body.toLowerCase();

      // Important: evaluate flagged/rejected first so "Not Published" is never mistaken as success.
      final isFlagged =
          type.endsWith('_flagged') ||
          lowerTitle.contains('not published') ||
          lowerTitle.contains('flagged') ||
          lowerTitle.contains('rejected') ||
          lowerBody.contains('flagged') ||
          lowerBody.contains('ai-generated') ||
          lowerBody.contains('potentially ai');

      final isPublished =
          type.endsWith('_published') ||
          (lowerTitle.endsWith('published') &&
              !lowerTitle.contains('not published')) ||
          lowerTitle.contains('success');

      final isUnderReview =
          type.endsWith('_review') || lowerTitle.endsWith('under review');

      if (isFlagged) {
        backgroundColor = Colors.red;
      } else if (isPublished) {
        backgroundColor = Colors.green;
      } else if (isUnderReview) {
        backgroundColor = Colors.amber.shade700;
      } else {
        backgroundColor = Colors.blue;
      }
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body.isNotEmpty ? body : title),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 7),
        ),
      );
  }

  /// Stop listening for real-time notifications
  void stopListening() {
    if (_notificationChannel != null) {
      _client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
    if (_supportMessageChannel != null) {
      _client.removeChannel(_supportMessageChannel!);
      _supportMessageChannel = null;
    }
  }

  Future<bool> _ensureSupportNotificationRow({
    required String userId,
    required String ticketId,
    required String title,
    required String body,
    String? actorId,
  }) async {
    try {
      final recent = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toIso8601String();
      List existing;
      try {
        // Preferred path when notifications table supports `ticket_id`.
        existing = await _client
            .from(SupabaseConfig.notificationsTable)
            .select('id')
            .eq('user_id', userId)
            .eq('ticket_id', ticketId)
            .eq('title', title)
            .eq('body', body)
            .gte('created_at', recent)
            .limit(1);
      } catch (_) {
        // Backward-compatible fallback for schemas without `ticket_id`.
        existing = await _client
            .from(SupabaseConfig.notificationsTable)
            .select('id')
            .eq('user_id', userId)
            .eq('title', title)
            .eq('body', body)
            .gte('created_at', recent)
            .limit(1);
      }

      if (existing.isNotEmpty) return true;

      var created = await _repository.createNotification(
        userId: userId,
        type: 'support_chat',
        title: title,
        body: body,
        actorId: actorId,
        ticketId: ticketId,
      );

      // Backward-compatible retry if insert failed because `ticket_id` column
      // is not yet present in the notifications table.
      if (!created) {
        created = await _repository.createNotification(
          userId: userId,
          type: 'support_chat',
          title: title,
          body: body,
          actorId: actorId,
        );
      }

      // Ensure the list updates even if realtime callback lags/skips.
      if (created) {
        await refreshNotifications(userId);
      }
      return created;
    } catch (e) {
      debugPrint(
        'NotificationProvider: Failed to ensure support notification row - $e',
      );
      return false;
    }
  }

  /// Filter notifications by type
  List<NotificationModel> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get unread notifications
  List<NotificationModel> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Load notifications for a user
  Future<void> loadNotifications(
    String userId, {
    bool onlyUnread = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final notifications = await _repository.getNotifications(
        userId: userId,
        onlyUnread: onlyUnread,
      );
      _notifications = notifications;
      _error = null;
    } catch (e) {
      _error = 'Failed to load notifications: $e';
      debugPrint('NotificationProvider: Error loading notifications - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh notifications
  Future<void> refreshNotifications(String userId) async {
    await loadNotifications(userId);
    await updateUnreadCount(userId);
  }

  /// Update unread count
  Future<void> updateUnreadCount(String userId) async {
    try {
      _unreadCount = await _repository.getUnreadCount(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationProvider: Error updating unread count - $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _repository.markAsRead(notificationId);
      if (success) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationProvider: Error marking notification as read - $e',
      );
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final success = await _repository.markAllAsRead(userId);
      if (success) {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationProvider: Error marking all as read - $e');
    }
  }

  /// Add a notification to the list (for real-time updates)
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }

  /// Remove a notification
  void removeNotification(String notificationId) {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => _notifications.first,
    );
    if (!notification.isRead) {
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    }
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Delete a notification (removes from DB and local list)
  Future<void> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    NotificationModel? removed;
    if (index != -1) {
      removed = _notifications[index];
      if (!removed.isRead) {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
      _notifications.removeAt(index);
      notifyListeners();
    }

    try {
      await _repository.deleteNotification(notificationId);
    } catch (e) {
      debugPrint('NotificationProvider: Error deleting notification - $e');
      // Revert on failure
      if (removed != null) {
        _notifications.insert(index, removed);
        if (!removed.isRead) {
          _unreadCount++;
        }
        notifyListeners();
      }
    }
  }

  /// Clear all notifications
  void clear() {
    stopListening();
    _notifications = [];
    _unreadCount = 0;
    _settings = null;
    _error = null;
    notifyListeners();
  }

  /// Load notification settings
  Future<void> loadSettings(String userId) async {
    try {
      _settings =
          await _repository.getNotificationSettings(userId) ??
          NotificationSettings(userId: userId);
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationProvider: Error loading settings - $e');
      _settings = NotificationSettings(userId: userId);
      notifyListeners();
    }
  }

  /// Update notification settings
  Future<bool> updateSettings(NotificationSettings settings) async {
    try {
      final success = await _repository.updateNotificationSettings(settings);
      if (success) {
        _settings = settings;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('NotificationProvider: Error updating settings - $e');
      return false;
    }
  }
}
