import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import '../models/notification_model.dart';
import '../models/notification_settings.dart';

/// Repository for notification-related Supabase operations.
class NotificationRepository {
  final _client = SupabaseService().client;

  String _normalizeType(String type) {
    // DB enum currently supports legacy social/system types.
    // Map newer AI status variants to `mention` so inserts don't fail.
    if (type.startsWith('post_') ||
        type.startsWith('comment_') ||
        type.startsWith('story_')) {
      return 'mention';
    }
    return type;
  }

  bool _isPreferenceEnabled(
    Map<String, dynamic> prefs,
    List<String> keys, {
    bool defaultValue = true,
  }) {
    for (final key in keys) {
      final value = prefs[key];
      if (value is bool) return value;
    }
    return defaultValue;
  }

  /// Fetch notifications for a user.
  /// Returns notifications ordered by most recent first.
  Future<List<NotificationModel>> getNotifications({
    required String userId,
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    try {
      debugPrint(
        'NotificationRepository: Fetching notifications for user=$userId',
      );

      var query = _client
          .from(SupabaseConfig.notificationsTable)
          .select('''
            *,
            actor:profiles!notifications_actor_id_fkey (
              user_id,
              username,
              display_name,
              avatar_url
            ),
            post:posts!notifications_post_id_fkey (
              id,
              title,
              body
            ),
            comment:comments!notifications_comment_id_fkey (
              id,
              body
            )
          ''')
          .eq('user_id', userId);

      if (onlyUnread) {
        query = query.eq('is_read', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint(
        'NotificationRepository: Fetched ${response.length} notifications',
      );

      return (response as List<dynamic>)
          .map((json) => NotificationModel.fromSupabase(json))
          .toList();
    } catch (e) {
      debugPrint('NotificationRepository: Error fetching notifications - $e');
      return [];
    }
  }

  /// Mark a notification as read.
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _client
          .from(SupabaseConfig.notificationsTable)
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint(
        'NotificationRepository: Error marking notification as read - $e',
      );
      return false;
    }
  }

  /// Mark all notifications as read for a user.
  Future<bool> markAllAsRead(String userId) async {
    try {
      await _client
          .from(SupabaseConfig.notificationsTable)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      debugPrint(
        'NotificationRepository: Error marking all notifications as read - $e',
      );
      return false;
    }
  }

  /// Get unread notification count for a user.
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.notificationsTable)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List<dynamic>).length;
    } catch (e) {
      debugPrint('NotificationRepository: Error getting unread count - $e');
      return 0;
    }
  }

  /// Create a notification.
  /// This is typically called by database triggers, but can be called manually.
  Future<bool> createNotification({
    required String userId,
    required String type, // 'like', 'comment', 'mention', 'follow'
    String? title,
    String? body,
    String? actorId,
    String? postId,
    String? commentId,
    String? storyId,
  }) async {
    try {
      final normalizedType = _normalizeType(type);
      debugPrint(
        'NotificationRepository: Creating notification type=$type (normalized=$normalizedType) for user=$userId from actor=$actorId',
      );

      // Don't create notification if user is notifying themselves
      if (actorId == userId) {
        debugPrint('NotificationRepository: Skipping self-notification');
        return false;
      }

      // Check user's notification preferences
      try {
        final prefs = await _client
            .from(SupabaseConfig.notificationPreferencesTable)
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (prefs != null) {
          bool enabled = true;
          switch (normalizedType) {
            case 'follow':
              enabled = _isPreferenceEnabled(prefs, ['inapp_follows']);
              break;
            case 'comment':
            case 'reply':
              enabled = _isPreferenceEnabled(prefs, [
                'inapp_comments',
                'notify_comments',
              ]);
              break;
            case 'like':
            case 'reaction':
              enabled = _isPreferenceEnabled(prefs, [
                'inapp_reactions',
                'notify_reactions',
              ]);
              break;
            case 'mention':
              enabled = _isPreferenceEnabled(prefs, [
                'inapp_mentions',
                'notify_mentions',
              ]);
              break;
            case 'roocoin_received':
            case 'roocoin_sent':
              enabled =
                  true; // Always notify for financial transactions for now
              break;
          }
          if (!enabled) {
            debugPrint(
              'NotificationRepository: Notification type=$type disabled by user preferences',
            );
            return false;
          }
        }
      } catch (e) {
        // If prefs check fails, we proceed anyway (assume enabled)
        debugPrint(
          'NotificationRepository: Warning - preferences check failed, proceeding anyway: $e',
        );
      }

      final data = {
        'user_id': userId,
        'type': normalizedType,
        'title': title,
        'body': body,
        'actor_id': actorId,
        'post_id': postId,
        'comment_id': commentId,
        'story_id': storyId,
        'is_read': false,
      };

      await _client.from(SupabaseConfig.notificationsTable).insert(data);

      debugPrint('NotificationRepository: Notification created successfully');
      return true;
    } catch (e) {
      debugPrint(
        'NotificationRepository: CRITICAL Error creating notification - $e',
      );
      // Potential RLS or Type Error
      return false;
    }
  }

  /// Delete a notification.
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _client
          .from(SupabaseConfig.notificationsTable)
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('NotificationRepository: Error deleting notification - $e');
      return false;
    }
  }

  /// Get notification settings for a user.
  Future<NotificationSettings?> getNotificationSettings(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.notificationPreferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return NotificationSettings.fromSupabase(response);
      }
      return NotificationSettings(userId: userId);
    } catch (e) {
      debugPrint('NotificationRepository: Error getting settings - $e');
      return null;
    }
  }

  /// Update notification settings for a user.
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    try {
      await _client
          .from(SupabaseConfig.notificationPreferencesTable)
          .upsert(settings.toSupabase());
      return true;
    } catch (e) {
      debugPrint('NotificationRepository: Error updating settings - $e');
      return false;
    }
  }
}
