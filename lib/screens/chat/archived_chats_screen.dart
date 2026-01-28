import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/conversation.dart';
import 'conversation_thread_page.dart';
import 'package:intl/intl.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations(showArchived: true);
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
          'Archived Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => chatProvider.loadConversations(showArchived: true),
        child: chatProvider.isLoading && chatProvider.conversations.isEmpty
            ? const Center(child: CircularProgressIndicator())
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
                  return _ArchivedConversationTile(
                    conversation: conversation,
                    currentUserId: currentUserId ?? '',
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            'No archived chats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;

  const _ArchivedConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation.otherParticipant(currentUserId);
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.blue.withOpacity(0.8),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          children: [
            Icon(Icons.unarchive, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Unarchive',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        context.read<ChatProvider>().unarchiveConversation(conversation.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation unarchived')),
        );
      },
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ConversationThreadPage(conversation: conversation),
            ),
          );
          if (context.mounted) {
            context.read<ChatProvider>().loadConversations(showArchived: true);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: otherUser.avatar != null
              ? NetworkImage(otherUser.avatar!)
              : null,
          child: otherUser.avatar == null
              ? Icon(Icons.person, color: colors.onSurfaceVariant)
              : null,
        ),
        title: Text(
          otherUser.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conversation.lastMessage?.content ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
        ),
        trailing: Text(
          _formatDateTime(conversation.lastMessageAt),
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat.Hm().format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(dateTime);
    } else {
      return DateFormat.Md().format(dateTime);
    }
  }
}
