import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../models/notification_settings.dart';
import '../repositories/notification_repository.dart';
import '../services/supabase_service.dart';
import '../config/supabase_config.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repository = NotificationRepository();
  final _client = SupabaseService().client;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  NotificationSettings? _settings;
  RealtimeChannel? _notificationChannel;

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
          },
        )
        .subscribe();

    debugPrint(
      'NotificationProvider: Listening for notifications for user=$userId',
    );
  }

  /// Stop listening for real-time notifications
  void stopListening() {
    if (_notificationChannel != null) {
      _client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
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
      _settings = await _repository.getNotificationSettings(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationProvider: Error loading settings - $e');
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
