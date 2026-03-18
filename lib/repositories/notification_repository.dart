import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';
import '../models/notification_model.dart';
import '../models/notification_settings.dart';

/// Repository for notification-related Supabase operations.
class NotificationRepository {
  final _client = SupabaseService().client;

  String _normalizeType(String type) {
    const supported = {
      'follow',
      'like',
      'comment',
      'mention',
      'reply',
      'repost',
      'message',
      'system',
      'moderation',
      'appeal_update',
      'verification',
      'roocoin_received',
      'roocoin_sent',
      'staking_reward',
      'achievement',
      'warning',
      'announcement',
    };

    // Map app-internal/newer types to the existing DB enum values.
    switch (type) {
      case 'chat':
      case 'support_chat':
        return 'message';
      case 'post_published':
      case 'post_review':
      case 'post_flagged':
      case 'comment_published':
      case 'comment_review':
      case 'comment_flagged':
      case 'story_published':
      case 'story_review':
      case 'story_flagged':
        return 'moderation';
      default:
        return supported.contains(type) ? type : 'mention';
    }
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

  /// Returns true if this notification type is a system/AI status notification
  /// that should always be shown regardless of user preferences.
  bool _isSystemType(String rawType) {
    return rawType.startsWith('post_') ||
        rawType.startsWith('comment_') ||
        rawType.startsWith('story_') ||
        rawType == 'roocoin_received' ||
        rawType == 'roocoin_sent' ||
        rawType == 'message' ||
        rawType == 'chat' ||
        rawType == 'support_chat' ||
        rawType == 'repost';
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

      List<dynamic> response;
      try {
        // Full query with joins for actor profile and related content.
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

        response = await query
            .order('created_at', ascending: false)
            .limit(limit);
      } catch (joinError) {
        // Fallback: fetch without joins if the FK-joined select fails.
        debugPrint(
          'NotificationRepository: Join query failed ($joinError), falling back to plain select',
        );
        var fallback = _client
            .from(SupabaseConfig.notificationsTable)
            .select('*')
            .eq('user_id', userId);

        if (onlyUnread) {
          fallback = fallback.eq('is_read', false);
        }

        response = await fallback
            .order('created_at', ascending: false)
            .limit(limit);
      }

      debugPrint(
        'NotificationRepository: Fetched ${response.length} notifications',
      );

      return response
          .map(
            (json) =>
                NotificationModel.fromSupabase(json as Map<String, dynamic>),
          )
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
    String? ticketId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final normalizedType = _normalizeType(type);

      // Don't create notification if user is notifying themselves
      if (actorId == userId) {
        return false;
      }

      // System/AI status notifications always go through regardless of preferences.
      if (!_isSystemType(type)) {
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
      }

      final data = <String, dynamic>{
        'user_id': userId,
        'type': normalizedType,
        'title': title,
        'body': body,
        'actor_id': actorId,
        'post_id': postId,
        'comment_id': commentId,
        'ticket_id': ticketId,
        'story_id': storyId,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        'is_read': false,
      };

      try {
        await _client.from(SupabaseConfig.notificationsTable).insert(data);
      } on PostgrestException catch (e) {
        // Some deployments still have older notification_type enums that don't
        // include newer AI/system types (e.g. post_published/story_review).
        // Fallback to an enum-safe type so notifications still insert and
        // real-time alert/push flow keeps working.
        final isEnumTypeError =
            e.code == '22P02' &&
            e.message.toLowerCase().contains('notification_type');

        if (isEnumTypeError && normalizedType != 'mention') {
          final fallbackData = <String, dynamic>{
            ...data,
            'type': 'mention',
            'metadata': {'original_type': normalizedType},
          };
          await _client
              .from(SupabaseConfig.notificationsTable)
              .insert(fallbackData);
          debugPrint(
            'NotificationRepository: Fallback insert succeeded with type=mention (original=$normalizedType)',
          );
        } else {
          rethrow;
        }
      }

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
