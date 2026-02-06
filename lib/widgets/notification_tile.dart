import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../config/app_colors.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : colors.primary.withOpacity(0.05),
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with Badge - System notifications show shield icon
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _isSystemNotification(notification.type)
                      ? _getBadgeColor(notification.type).withOpacity(0.15)
                      : colors.surfaceVariant,
                  backgroundImage: !_isSystemNotification(notification.type) &&
                          notification.actor?.avatarUrl != null
                      ? NetworkImage(notification.actor!.avatarUrl!)
                      : null,
                  child: _isSystemNotification(notification.type)
                      ? Icon(
                          Icons.shield,
                          color: _getBadgeColor(notification.type),
                          size: 24,
                        )
                      : notification.actor?.avatarUrl == null
                          ? Icon(Icons.person, color: colors.onSurfaceVariant)
                          : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getBadgeColor(notification.type),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: Icon(
                      _getIcon(notification.type),
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Notification Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System notifications (AI check, etc.) show title directly
                  // User notifications show "[actor] [verb]" format
                  if (_isSystemNotification(notification.type))
                    Text(
                      notification.getDisplayTitle(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    )
                  else
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text:
                                notification.actor?.displayName ??
                                notification.actor?.username ??
                                'Someone',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: _getVerb(notification.type)),
                        ],
                      ),
                    ),

                  if (notification.getDisplayBody().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.getDisplayBody(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),
                  Text(
                    notification.getTimeAgo(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Post Preview if available
            if (notification.postId != null && notification.post != null)
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Icon(
                    Icons.article_outlined,
                    size: 20,
                    color: colors.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBadgeColor(String type) {
    switch (type) {
      case 'like':
      case 'reaction':
        return Colors.redAccent;
      case 'comment':
      case 'reply':
        return Colors.blueAccent;
      case 'roocoin_received':
      case 'roocoin_sent':
        return Colors.amber;
      case 'mention':
        return Colors.orangeAccent;
      case 'follow':
        return Colors.greenAccent;
      // AI Check - Published (green)
      case 'post_published':
      case 'comment_published':
      case 'story_published':
        return const Color(0xFF10B981);
      // AI Check - Under Review (amber)
      case 'post_review':
      case 'comment_review':
      case 'story_review':
        return Colors.amber;
      // AI Check - Flagged (red)
      case 'post_flagged':
      case 'comment_flagged':
      case 'story_flagged':
        return Colors.redAccent;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'like':
      case 'reaction':
        return Icons.favorite;
      case 'comment':
      case 'reply':
        return Icons.chat_bubble;
      case 'roocoin_received':
      case 'roocoin_sent':
        return Icons.account_balance_wallet;
      case 'mention':
        return Icons.alternate_email;
      case 'follow':
        return Icons.person_add;
      // AI Check - Published
      case 'post_published':
      case 'comment_published':
      case 'story_published':
        return Icons.check_circle;
      // AI Check - Under Review
      case 'post_review':
      case 'comment_review':
      case 'story_review':
        return Icons.pending;
      // AI Check - Flagged
      case 'post_flagged':
      case 'comment_flagged':
      case 'story_flagged':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  String _getVerb(String type) {
    switch (type) {
      case 'like':
      case 'reaction':
        return 'liked your post';
      case 'comment':
        return 'commented on your post';
      case 'reply':
        return 'replied to your comment';
      case 'roocoin_received':
        return 'sent you RooCoin';
      case 'roocoin_sent':
        return 'successfully sent RooCoin';
      case 'mention':
        return 'mentioned you';
      case 'follow':
        return 'started following you';
      default:
        return 'interacted with you';
    }
  }

  /// Check if this is a system notification (no actor needed)
  bool _isSystemNotification(String type) {
    return type.startsWith('post_') ||
        type.startsWith('comment_') ||
        type.startsWith('story_');
  }
}
