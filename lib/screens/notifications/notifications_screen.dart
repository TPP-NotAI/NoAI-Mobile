import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
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
import '../../models/conversation.dart';
import '../../models/notification_model.dart';
import '../../services/supabase_service.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notificationProvider = context.watch<NotificationProvider>();
    final authProvider = context.read<AuthProvider>();

    final all = notificationProvider.notifications;
    final unread = all.where((n) => !n.isRead).toList();
    final roochip = all
        .where((n) =>
            n.type == 'roocoin_received' || n.type == 'roocoin_sent')
        .toList();
    final system = all
        .where((n) =>
            n.type.startsWith('post_') ||
            n.type.startsWith('comment_') ||
            n.type.startsWith('story_') ||
            n.type == 'support_chat')
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications'.tr(context),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          // Overflow menu — matches reference design
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification settings',
            onSelected: (value) {
              switch (value) {
                case 'mark_all':
                  if (authProvider.currentUser != null) {
                    notificationProvider.markAllAsRead(
                        authProvider.currentUser!.id);
                  }
                  break;
                case 'clear_viewed':
                  _clearViewed(notificationProvider);
                  break;
                case 'clear_all':
                  _confirmClearAll(context, notificationProvider, authProvider);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mark_all',
                child: Row(
                  children: [
                    const Icon(Icons.done_all, size: 18),
                    const SizedBox(width: 10),
                    Text('Mark all as read'.tr(context)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_viewed',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text('Clear viewed'.tr(context)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: colors.error),
                    const SizedBox(width: 10),
                    Text(
                      'Clear all notifications'.tr(context),
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
          tabs: [
            _TabWithBadge(
                label: 'All'.tr(context), count: notificationProvider.unreadCount),
            Tab(text: 'Unread'.tr(context)),
            Tab(text: 'Roochip'.tr(context)),
            Tab(text: 'System'.tr(context)),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          if (authProvider.currentUser != null) {
            await notificationProvider.refreshNotifications(
              authProvider.currentUser!.id,
            );
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildList(context, notificationProvider, all),
            _buildList(context, notificationProvider, unread,
                emptyMessage: 'No unread notifications'.tr(context)),
            _buildList(context, notificationProvider, roochip,
                emptyMessage: 'No Roochip notifications'.tr(context)),
            _buildList(context, notificationProvider, system,
                emptyMessage: 'No system notifications'.tr(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    NotificationProvider provider,
    List<NotificationModel> notifications, {
    String? emptyMessage,
  }) {
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

    if (notifications.isEmpty) {
      return _buildEmptyState(context, emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
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
                    content: Text(
                      'Are you sure you want to delete this notification?'
                          .tr(context),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child:
                            Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Delete'.tr(context),
                          style: const TextStyle(color: Colors.red),
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
              SnackBar(
                  content: Text('Notification deleted'.tr(context))),
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

  Widget _buildEmptyState(BuildContext context, String? message) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: AppColors.primary.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message ?? 'All caught up',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll be notified when someone likes, comments, or interacts with you',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearViewed(NotificationProvider provider) {
    final read = provider.notifications.where((n) => n.isRead).toList();
    for (final n in read) {
      provider.deleteNotification(n.id);
    }
  }

  void _confirmClearAll(
    BuildContext context,
    NotificationProvider provider,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear all notifications'.tr(context)),
        content: Text(
            'This will permanently delete all your notifications.'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              for (final n in List.of(provider.notifications)) {
                provider.deleteNotification(n.id);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Clear all'.tr(context)),
          ),
        ],
      ),
    );
  }

  void _handleNotificationNavigation(NotificationModel notification) async {
    final colors = Theme.of(context).colorScheme;

    if (_isAdminAnnouncementNotification(notification)) return;
    if (_isAdminProfileNotification(notification)) return;

    if (_isSupportChatNotification(notification)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SupportChatScreen(initialTicketId: notification.ticketId),
        ),
      );
      return;
    }

    if (_isDirectMessageNotification(notification) &&
        notification.actorId != null) {
      final chatProvider = context.read<ChatProvider>();
      Conversation? conversation;

      final threadId = await _resolveNotificationThreadId(notification.id);
      if (threadId != null) {
        var index =
            chatProvider.conversations.indexWhere((c) => c.id == threadId);
        if (index == -1) {
          await chatProvider.loadConversations();
          if (!mounted) return;
          index =
              chatProvider.conversations.indexWhere((c) => c.id == threadId);
        }
        if (index != -1) conversation = chatProvider.conversations[index];
      }

      conversation ??=
          await chatProvider.startConversation(notification.actorId!);

      if (!mounted) return;

      if (conversation != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ConversationThreadPage(conversation: conversation!),
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

    if (notification.postId != null) {
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
    } else if (notification.actorId != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
                userId: notification.actorId, showAppBar: true),
          ),
        );
      }
    }
  }

  Future<String?> _resolveNotificationThreadId(String notificationId) async {
    try {
      final row = await SupabaseService().client
          .from('notifications')
          .select('metadata')
          .eq('id', notificationId)
          .maybeSingle();
      final metadata = row?['metadata'];
      if (metadata is Map<String, dynamic>) {
        final threadId = metadata['thread_id']?.toString().trim();
        if (threadId != null && threadId.isNotEmpty) return threadId;
      }
    } catch (_) {}
    return null;
  }

  bool _isDirectMessageNotification(NotificationModel notification) {
    final rawType = notification.type.toLowerCase();
    if (rawType == 'message' || rawType == 'chat') return true;
    return rawType == 'mention' &&
        notification.actorId != null &&
        notification.postId == null &&
        notification.commentId == null &&
        (notification.title?.trim().isNotEmpty ?? false);
  }

  bool _isSupportChatNotification(NotificationModel notification) {
    final rawType = notification.type.toLowerCase();
    if (rawType == 'support_chat') return true;
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
    if (notification.postId != null) return false;
    if (_isSupportChatNotification(notification)) return false;
    if (_isDirectMessageNotification(notification)) return false;
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

/// Tab with an optional unread count badge
class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabWithBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
