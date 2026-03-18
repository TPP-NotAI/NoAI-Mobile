import 'dart:async';
import '../../config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/dm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/dm_thread.dart';
import '../../models/user.dart';
import '../../widgets/shimmer_loading.dart';
import 'dm_thread_page.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

class DmListScreen extends StatefulWidget {
  const DmListScreen({super.key});

  @override
  State<DmListScreen> createState() => _DmListScreenState();
}

class _DmListScreenState extends State<DmListScreen>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DmProvider>().loadThreads();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<DmProvider>().loadThreads();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dmProvider = context.watch<DmProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';

    final allThreads = dmProvider.threads;
    final unreadThreads = allThreads.where((t) => t.unreadCount > 0).toList();
    final archivedThreads = <DmThread>[]; // extend when archived flag is added
    final supportThreads = allThreads
        .where((t) => _isSupportThread(t, currentUserId))
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        tooltip: 'New message',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Start a DM from a user\'s profile!'.tr(context)),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: const Icon(Icons.edit_outlined),
      ),
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search Direct Messages'.tr(context),
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close,
                                color: colors.onSurfaceVariant, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                isScrollable: false,
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
                  Tab(text: 'All'.tr(context)),
                  Tab(text: 'Unread'.tr(context)),
                  Tab(text: 'Archived'.tr(context)),
                  Tab(text: 'Support'.tr(context)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => dmProvider.loadThreads(),
        child: dmProvider.isLoading && dmProvider.threads.isEmpty
            ? ListView.builder(
                itemCount: 8,
                itemBuilder: (_, __) => const ShimmerLoading(
                  isLoading: true,
                  child: ChatListItemShimmer(),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildThreadList(context, allThreads, currentUserId),
                  _buildThreadList(context, unreadThreads, currentUserId,
                      emptyMessage: 'No unread messages'.tr(context)),
                  _buildThreadList(context, archivedThreads, currentUserId,
                      emptyMessage: 'No archived messages'.tr(context)),
                  _buildThreadList(context, supportThreads, currentUserId,
                      emptyMessage: 'No support messages'.tr(context)),
                ],
              ),
      ),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    List<DmThread> threads,
    String currentUserId, {
    String? emptyMessage,
  }) {
    final filtered = _searchQuery.isEmpty
        ? threads
        : threads.where((t) {
            final other = t.otherParticipant(currentUserId);
            return other.displayName
                    .toLowerCase()
                    .contains(_searchQuery) ||
                (t.lastMessage?.body ?? '')
                    .toLowerCase()
                    .contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(context, emptyMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 76,
        endIndent: 16,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        final thread = filtered[index];
        return _DmThreadTile(thread: thread, currentUserId: currentUserId);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String? message) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              size: 34,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No direct messages yet'.tr(context),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a DM from someone\'s profile!'.tr(context),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  bool _isSupportThread(DmThread thread, String currentUserId) {
    final other = thread.otherParticipant(currentUserId);
    final name = other.displayName.toLowerCase();
    final username = (other.username ?? '').toLowerCase();
    return name.contains('support') ||
        name.contains('admin') ||
        username.contains('support') ||
        username.contains('admin');
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
    final theme = Theme.of(context);
    final hasUnread = thread.unreadCount > 0;

    return Dismissible(
      key: Key(thread.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error.withValues(alpha: 0.85),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete'.tr(context),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete Conversation'.tr(context)),
            content: Text(
              'Are you sure you want to delete this conversation? This action cannot be undone.'
                  .tr(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        context.read<DmProvider>().deleteThread(thread.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversation deleted'.tr(context))),
        );
      },
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DmThreadPage(thread: thread)),
          );
          if (context.mounted) {
            context.read<DmProvider>().loadThreads();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(otherUser, colors),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUser.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            hasUnread ? FontWeight.bold : FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _lastMessagePreview(thread),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasUnread
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDateTime(thread.lastMessageAt ?? thread.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasUnread
                          ? AppColors.primary
                          : colors.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: hasUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${thread.unreadCount}',
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
            ],
          ),
        ),
      ),
    );
  }

  String _lastMessagePreview(DmThread thread) {
    return thread.lastMessage?.body ?? '';
  }

  Widget _buildAvatar(User otherUser, ColorScheme colors) {
    final now = DateTime.now();
    final isOnline = otherUser.lastSeen != null &&
        now.difference(otherUser.lastSeen!).inMinutes < 5;

    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage:
              otherUser.avatar != null ? NetworkImage(otherUser.avatar!) : null,
          child: otherUser.avatar == null
              ? Icon(Icons.person, color: colors.onSurfaceVariant)
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);
    if (diff.inDays == 0) return DateFormat.Hm().format(local);
    if (diff.inDays < 7) return DateFormat.E().format(local);
    return DateFormat.Md().format(local);
  }
}
