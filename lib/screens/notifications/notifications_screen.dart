import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_tile.dart';
import '../../widgets/loading_widget.dart';
import '../post_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/feed_provider.dart';
import '../../models/notification_model.dart';

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
        title: Text(
          'Notifications',
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
              child: const Text('Mark all read'),
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
              child: const Text('Retry'),
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
            Text(
              'No notifications yet',
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
                title: const Text('Delete Notification'),
                content: const Text('Are you sure you want to delete this notification?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (direction) {
            provider.deleteNotification(notification.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification deleted')),
            );
          },
          child: NotificationTile(
            notification: notification,
            onTap: () {
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
            content: const Text('Post not found or unavailable'),
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
            builder: (_) => ProfileScreen(userId: notification.actorId, showAppBar: true),
          ),
        );
      }
    }
  }
}
