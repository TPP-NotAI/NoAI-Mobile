import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/dm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/dm_thread.dart';
import '../../widgets/shimmer_loading.dart';
import 'dm_thread_page.dart';

class DmListScreen extends StatefulWidget {
  const DmListScreen({super.key});

  @override
  State<DmListScreen> createState() => _DmListScreenState();
}

class _DmListScreenState extends State<DmListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DmProvider>().loadThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dmProvider = context.watch<DmProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Direct Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => dmProvider.loadThreads(),
        child: dmProvider.isLoading && dmProvider.threads.isEmpty
            ? ListView.builder(
                itemCount: 10,
                itemBuilder: (context, index) => const ShimmerLoading(
                  isLoading: true,
                  child: ChatListItemShimmer(),
                ),
              )
            : dmProvider.threads.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    itemCount: dmProvider.threads.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 80,
                      color: colors.outlineVariant.withOpacity(0.5),
                    ),
                    itemBuilder: (context, index) {
                      final thread = dmProvider.threads[index];
                      return _DmThreadTile(
                        thread: thread,
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
          Icon(Icons.mail_outline, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            'No direct messages yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a DM from someone\'s profile!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _DmThreadTile extends StatelessWidget {
  final DmThread thread;
  final String currentUserId;

  const _DmThreadTile({
    required this.thread,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = thread.otherParticipant(currentUserId);
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(thread.id),
      direction: DismissDirection.endToStart,
      background: Container(
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
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete DM Thread'),
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
      },
      onDismissed: (_) {
        context.read<DmProvider>().deleteThread(thread.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DM thread deleted')),
        );
      },
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DmThreadPage(thread: thread),
            ),
          );
          if (context.mounted) {
            context.read<DmProvider>().loadThreads();
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage:
              otherUser.avatar != null ? NetworkImage(otherUser.avatar!) : null,
          child: otherUser.avatar == null
              ? Icon(Icons.person, color: colors.onSurfaceVariant)
              : null,
        ),
        title: Text(
          otherUser.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: colors.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            thread.lastMessage?.body ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        trailing: Text(
          _formatDateTime(thread.lastMessageAt ?? thread.createdAt),
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
