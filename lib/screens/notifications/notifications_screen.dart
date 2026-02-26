import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_tile.dart';
import '../../widgets/loading_widget.dart';
import '../post_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/conversation_thread_page.dart';
import '../support/support_chat_screen.dart';
import '../../providers/feed_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/notification_model.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        context.read<NotificationProvider>().refreshNotifications(
          authProvider.currentUser!.id,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notificationProvider = context.watch<NotificationProvider>();
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Notifications'.tr(context),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton(
              onPressed: () {
                if (authProvider.currentUser != null) {
                  notificationProvider.markAllAsRead(
                    authProvider.currentUser!.id,
                  );
                }
              },
              child: Text('Mark all read'.tr(context)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (authProvider.currentUser != null) {
            await notificationProvider.refreshNotifications(
              authProvider.currentUser!.id,
            );
          }
        },
        child: _buildBody(notificationProvider),
      ),
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    if (provider.error != null && provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final authProvider = context.read<AuthProvider>();
                if (authProvider.currentUser != null) {
                  provider.refreshNotifications(authProvider.currentUser!.id);
                }
              },
              child: Text('Retry'.tr(context)),
            ),
          ],
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text('No notifications yet'.tr(context),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: provider.notifications.length,
      itemBuilder: (context, index) {
        final notification = provider.notifications[index];
        return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Notification'.tr(context)),
                    content: Text('Are you sure you want to delete this notification?'.tr(context),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('Delete'.tr(context),
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (direction) {
            provider.deleteNotification(notification.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Notification deleted'.tr(context))),
            );
          },
          child: NotificationTile(
            notification: notification,
            onTap: (_isAdminAnnouncementNotification(notification) ||
                    _isAdminProfileNotification(notification))
                ? null
                : () {
                    provider.markAsRead(notification.id);
                    _handleNotificationNavigation(notification);
                  },
          ),
        );
      },
    );
  }

  void _handleNotificationNavigation(NotificationModel notification) async {
    final colors = Theme.of(context).colorScheme;

    if (_isAdminAnnouncementNotification(notification)) {
      return;
    }

    if (_isAdminProfileNotification(notification)) {
      return;
    }

    if (_isSupportChatNotification(notification)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(initialTicketId: notification.ticketId),
        ),
      );
      return;
    }

    // Direct message/chat notification (message/chat types are normalized to
    // mention in the repository, so we infer using the metadata shape).
    if (_isDirectMessageNotification(notification) &&
        notification.actorId != null) {
      final chatProvider = context.read<ChatProvider>();
      final conversation = await chatProvider.startConversation(
        notification.actorId!,
      );

      if (!mounted) return;

      if (conversation != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationThreadPage(conversation: conversation),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open chat'.tr(context)),
            backgroundColor: colors.error,
          ),
        );
      }
      return;
    }

    // Navigate to post or comment
    if (notification.postId != null) {
      // Find the post first
      final feedProvider = context.read<FeedProvider>();
      final post = await feedProvider.getPostById(notification.postId!);

      if (post != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post not found or unavailable'.tr(context)),
            backgroundColor: colors.error,
          ),
        );
      }
    }
    // Navigate to user profile
    else if (notification.actorId != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileScreen(userId: notification.actorId, showAppBar: true),
          ),
        );
      }
    }
  }

  bool _isDirectMessageNotification(NotificationModel notification) {
    final rawType = notification.type.toLowerCase();
    if (rawType == 'message' || rawType == 'chat') {
      return true;
    }

    // message/chat notifications are currently normalized to `mention`
    // before insert, but they keep sender title and actor_id and have no post/comment.
    return rawType == 'mention' &&
        notification.actorId != null &&
        notification.postId == null &&
        notification.commentId == null &&
        (notification.title?.trim().isNotEmpty ?? false);
  }

  bool _isSupportChatNotification(NotificationModel notification) {
    final rawType = notification.type.toLowerCase();
    if (rawType == 'support_chat') return true;

    // `support_chat` may be normalized to `mention` in the repository.
    final title = (notification.title ?? '').toLowerCase();
    final body = (notification.body ?? '').toLowerCase();
    final actorName = (notification.actor?.displayName ?? '').toLowerCase();
    final actorUsername = (notification.actor?.username ?? '').toLowerCase();
    final isAdminLikeActor = actorName.contains('admin') ||
        actorName.contains('support') ||
        actorUsername.contains('admin') ||
        actorUsername.contains('support');

    return rawType == 'mention' &&
        notification.postId == null &&
        notification.commentId == null &&
        !(_isAdminAnnouncementNotification(notification)) &&
        (title.startsWith('support:') ||
            title.contains('support chat') ||
            body.contains('ticket') ||
            body.contains('replied in') ||
            (isAdminLikeActor && body.contains('support')));
  }

  bool _isAdminAnnouncementNotification(NotificationModel notification) {
    final rawType = notification.type.toLowerCase();
    if (rawType == 'support_chat') return false;

    final title = (notification.title ?? '').toLowerCase();
    final body = (notification.body ?? '').toLowerCase();
    final actorName = (notification.actor?.displayName ?? '').toLowerCase();
    final actorUsername = (notification.actor?.username ?? '').toLowerCase();
    final isAdminLikeActor = actorName.contains('admin') ||
        actorName.contains('support') ||
        actorUsername.contains('admin') ||
        actorUsername.contains('support');

    final looksAnnouncement = title.contains('update') ||
        title.contains('announcement') ||
        title.contains('notice') ||
        title.contains('maintenance') ||
        title.contains('new update');

    return rawType == 'mention' &&
        notification.postId == null &&
        notification.commentId == null &&
        isAdminLikeActor &&
        looksAnnouncement &&
        !title.startsWith('support:');
  }

  bool _isAdminProfileNotification(NotificationModel notification) {
    if (notification.actorId == null) return false;
    if (notification.postId != null) return false; // opens post
    if (_isSupportChatNotification(notification)) return false; // opens support chat
    if (_isDirectMessageNotification(notification)) return false; // opens chat

    final actorName = (notification.actor?.displayName ?? '').toLowerCase();
    final actorUsername = (notification.actor?.username ?? '').toLowerCase();
    final title = (notification.title ?? '').toLowerCase();
    final body = (notification.body ?? '').toLowerCase();

    final actorLooksAdmin = actorName.contains('admin') ||
        actorName.contains('support') ||
        actorUsername.contains('admin') ||
        actorUsername.contains('support');

    final contentLooksAdmin = title.contains('admin') ||
        title.contains('support') ||
        body.contains('admin') ||
        body.contains('support');

    return actorLooksAdmin || contentLooksAdmin;
  }
}


