import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../config/app_colors.dart';
import 'package:rooverse/l10n/hardcoded_l10n.dart';

class NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  static const int _readMoreThreshold = 140;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notification = widget.notification;
    final isSupportLike = _isSupportLikeNotification(notification);
    final bodyText = notification.getDisplayBody();
    final canExpand = bodyText.length > _readMoreThreshold;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
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
                    backgroundColor: _isSystemNotification(notification)
                        ? _getBadgeColor(notification.type).withOpacity(0.15)
                        : colors.surfaceVariant,
                    backgroundImage:
                        !_isSystemNotification(notification) &&
                            notification.actor?.avatarUrl != null
                        ? NetworkImage(notification.actor!.avatarUrl!)
                        : null,
                    child: _isSystemNotification(notification)
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
                    // Always use getDisplayTitle() which already embeds the actor
                    // name for social types. For true social interactions where we
                    // want the actor name bolded, use RichText only when:
                    // - it is NOT a system notification, AND
                    // - the title field is not explicitly set (so the actor+verb
                    //   format is appropriate rather than a custom stored title).
                    if (_isSystemNotification(notification) ||
                        (notification.title != null &&
                            notification.title!.isNotEmpty))
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(text: _getVerb(notification.type)),
                          ],
                        ),
                      ),

                    if (bodyText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bodyText,
                        maxLines: _expanded ? null : (isSupportLike ? 4 : 2),
                        overflow:
                            _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (canExpand)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() => _expanded = !_expanded),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(top: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              _expanded
                                  ? 'Read less'.tr(context)
                                  : 'Read more'.tr(context),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      case 'chat':
      case 'message':
        return Colors.teal;
      case 'repost':
        return Colors.teal;
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
      case 'chat':
      case 'message':
        return Icons.message;
      case 'repost':
        return Icons.repeat;
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
        return 'sent you Roobyte';
      case 'roocoin_sent':
        return 'successfully sent Roobyte';
      case 'chat':
      case 'message':
        return 'sent you a message';
      case 'repost':
        return 'reposted your post';
      case 'mention':
        return 'You were mentioned in a post';
      case 'follow':
        return 'started following you';
      default:
        return 'interacted with you';
    }
  }

  /// Check if this is a system notification (no actor needed)
  bool _isSystemNotification(NotificationModel notification) {
    final type = notification.type;
    return type.startsWith('post_') ||
        type.startsWith('comment_') ||
        type.startsWith('story_') ||
        _isSupportLikeNotification(notification) ||
        type == 'chat' ||
        type == 'message' ||
        (type == 'mention' && notification.actorId == null);
  }

  bool _isSupportLikeNotification(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    final title = (notification.title ?? '').toLowerCase();
    final body = (notification.body ?? '').toLowerCase();
    final actorName = (notification.actor?.displayName ?? '').toLowerCase();
    final actorUsername = (notification.actor?.username ?? '').toLowerCase();

    final actorLooksSupport = actorName.contains('admin') ||
        actorName.contains('support') ||
        actorUsername.contains('admin') ||
        actorUsername.contains('support');

    final titleLooksSupport = title.contains('support') ||
        title.contains('update') ||
        title.contains('announcement') ||
        title.contains('notice') ||
        title.contains('maintenance');

    return type == 'support_chat' ||
        (type == 'mention' &&
            notification.postId == null &&
            notification.commentId == null &&
            (actorLooksSupport ||
                titleLooksSupport ||
                body.contains('support team')));
  }
}
