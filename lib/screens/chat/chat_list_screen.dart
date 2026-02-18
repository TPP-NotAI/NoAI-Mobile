import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/conversation.dart';
import 'conversation_thread_page.dart';
import 'archived_chats_screen.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../wallet/user_search_sheet.dart';
import '../../widgets/shimmer_loading.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatProvider = context.watch<ChatProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
              );
            },
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived Chats',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => chatProvider.loadConversations(),
        child: chatProvider.isLoading && chatProvider.conversations.isEmpty
            ? ListView.builder(
                itemCount: 10,
                itemBuilder: (context, index) => const ShimmerLoading(
                  isLoading: true,
                  child: ChatListItemShimmer(),
                ),
              )
            : chatProvider.conversations.isEmpty
            ? _buildEmptyState(context)
            : ListView.separated(
                itemCount: chatProvider.conversations.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 80,
                  color: colors.outlineVariant.withOpacity(0.5),
                ),
                itemBuilder: (context, index) {
                  final conversation = chatProvider.conversations[index];
                  return _ConversationTile(
                    conversation: conversation,
                    currentUserId: currentUserId ?? '',
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewMessage(context),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        child: const Icon(Icons.add_comment_outlined),
        tooltip: 'New Message',
      ),
    );
  }

  Future<void> _createNewMessage(BuildContext context) async {
    final selectedUser = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UserSearchSheet(),
    );

    if (selectedUser != null && mounted) {
      final chatProvider = context.read<ChatProvider>();
      final conversation = await chatProvider.startConversation(
        selectedUser.id,
      );

      if (conversation != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationThreadPage(conversation: conversation),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with someone!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _createNewMessage(context),
            icon: const Icon(Icons.add),
            label: const Text('Start Messaging'),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation.otherParticipant(currentUserId);
    final colors = Theme.of(context).colorScheme;
    final hasUnread = conversation.unreadCount > 0;

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.orange.withOpacity(0.8),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          children: [
            Icon(Icons.archive, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Archive',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red.withOpacity(0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Conversation'),
              content: const Text(
                'Are you sure you want to delete this conversation? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        }
        return true; // Archive doesn't need confirmation
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          context.read<ChatProvider>().archiveConversation(conversation.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation archived')),
          );
        } else {
          context.read<ChatProvider>().deleteConversationForUser(
            conversation.id,
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
        }
      },
      child: ListTile(
        onTap: () async {
          if (conversation.unreadCount > 0) {
            await context.read<ChatProvider>().markAsRead(conversation.id);
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ConversationThreadPage(conversation: conversation),
            ),
          );
          // Refresh conversations when returning from chat
          if (context.mounted) {
            context.read<ChatProvider>().loadConversations();
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: otherUser.avatar != null
                  ? NetworkImage(otherUser.avatar!)
                  : null,
              child: otherUser.avatar == null
                  ? Icon(Icons.person, color: colors.onSurfaceVariant)
                  : null,
            ),
            if (otherUser.id ==
                'support_user_id') // Example indicator for support
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          otherUser.displayName,
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
            color: colors.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conversation.lastMessage?.displayContent ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? colors.onSurface : colors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDateTime(conversation.lastMessageAt),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread
                    ? colors.primary
                    : colors.onSurfaceVariant.withOpacity(0.7),
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = dateTime.toLocal();
    final difference = now.difference(localDateTime);

    if (difference.inDays == 0) {
      return DateFormat.Hm().format(localDateTime);
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(localDateTime);
    } else {
      return DateFormat.Md().format(localDateTime);
    }
  }
}
