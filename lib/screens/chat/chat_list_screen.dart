import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/conversation.dart';
import 'conversation_thread_page.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../wallet/user_search_sheet.dart';
import '../support/support_chat_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../config/app_colors.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Archived conversations loaded separately
  List<Conversation> _archivedConversations = [];
  bool _archivedLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  void _onTabChanged() {
    if (_tabController.index == 2 && _archivedConversations.isEmpty) {
      _loadArchived();
    }
  }

  Future<void> _loadArchived() async {
    if (!mounted) return;
    setState(() => _archivedLoading = true);
    final provider = context.read<ChatProvider>();
    await provider.loadConversations(showArchived: true);
    if (mounted) {
      setState(() {
        _archivedConversations = provider.conversations;
        _archivedLoading = false;
      });
      // Reload normal conversations to restore normal view
      provider.loadConversations();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatProvider = context.watch<ChatProvider>();
    final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';

    final allConversations = chatProvider.conversations
        .where((c) => !_isSupportConversation(c, currentUserId))
        .toList();
    final unreadConversations =
        allConversations.where((c) => c.unreadCount > 0).toList();
    final supportConversations = chatProvider.conversations
        .where((c) => _isSupportConversation(c, currentUserId))
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewMessage(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        tooltip: 'New Message',
        child: const Icon(Icons.edit_outlined),
      ),
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text(
          'Messages'.tr(context),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
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
        onRefresh: () => chatProvider.loadConversations(),
        child: chatProvider.isLoading && chatProvider.conversations.isEmpty
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
                  _buildList(context, allConversations, currentUserId),
                  _buildList(
                    context,
                    unreadConversations,
                    currentUserId,
                    emptyMessage: 'No unread messages'.tr(context),
                  ),
                  _buildArchivedTab(context, currentUserId),
                  _buildSupportTab(context, supportConversations, currentUserId),
                ],
              ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Conversation> conversations,
    String currentUserId, {
    String? emptyMessage,
    bool isArchived = false,
  }) {
    final filtered = _searchQuery.isEmpty
        ? conversations
        : conversations.where((c) {
            final other = c.otherParticipant(currentUserId);
            return other.displayName.toLowerCase().contains(_searchQuery) ||
                (c.lastMessage?.displayContent ?? '')
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
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        return _ConversationTile(
          conversation: filtered[index],
          currentUserId: currentUserId,
          isArchived: isArchived,
          onUnarchived: isArchived ? () => _loadArchived() : null,
        );
      },
    );
  }

  Widget _buildArchivedTab(BuildContext context, String currentUserId) {
    if (_archivedLoading) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerLoading(
          isLoading: true,
          child: ChatListItemShimmer(),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadArchived,
      child: _buildList(
        context,
        _archivedConversations,
        currentUserId,
        emptyMessage: 'No archived chats'.tr(context),
        isArchived: true,
      ),
    );
  }

  Widget _buildSupportTab(
    BuildContext context,
    List<Conversation> supportConversations,
    String currentUserId,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Open support chat button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportChatScreen()),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Support'.tr(context),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface,
                                  ),
                        ),
                        Text(
                          'Get help from our team'.tr(context),
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        if (supportConversations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Support Conversations'.tr(context),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
          ),
          Expanded(
            child: _buildList(context, supportConversations, currentUserId),
          ),
        ] else
          Expanded(
            child: _buildEmptyState(
              context,
              'No support conversations yet'.tr(context),
              icon: Icons.headset_mic_outlined,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String? message,
      {IconData icon = Icons.mail_outline_rounded}) {
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
            child: Icon(icon, size: 34,
                color: AppColors.primary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No messages yet'.tr(context),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with someone!'.tr(context),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  bool _isSupportConversation(Conversation conversation, String currentUserId) {
    final other = conversation.otherParticipant(currentUserId);
    final haystack =
        '${other.id} ${other.username} ${other.displayName}'.toLowerCase();
    return haystack.contains('support') ||
        haystack.contains('helpdesk') ||
        haystack.contains('customer care');
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
      final conversation = await chatProvider.startConversation(selectedUser.id);

      if (conversation != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationThreadPage(conversation: conversation),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatProvider.error ??
                  'You can only start chats with users you follow.',
            ),
          ),
        );
      }
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final bool isArchived;
  final VoidCallback? onUnarchived;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    this.isArchived = false,
    this.onUnarchived,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation.otherParticipant(currentUserId);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasUnread = conversation.unreadCount > 0;

    return Dismissible(
      key: Key(conversation.id),
      direction: isArchived
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      background: isArchived
          ? null
          : Container(
              color: Colors.orange.withValues(alpha: 0.8),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.archive, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Archive'.tr(context),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
      secondaryBackground: Container(
        color: isArchived
            ? Colors.green.withValues(alpha: 0.8)
            : Colors.red.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              isArchived ? 'Unarchive'.tr(context) : 'Delete'.tr(context),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(
              isArchived ? Icons.unarchive_outlined : Icons.delete,
              color: Colors.white,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (!isArchived && direction == DismissDirection.endToStart) {
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
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(AppLocalizations.of(context)!.delete),
                ),
              ],
            ),
          );
        }
        return true;
      },
      onDismissed: (direction) {
        if (isArchived) {
          context.read<ChatProvider>().unarchiveConversation(conversation.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conversation unarchived'.tr(context))),
          );
          onUnarchived?.call();
        } else if (direction == DismissDirection.startToEnd) {
          context.read<ChatProvider>().archiveConversation(conversation.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conversation archived'.tr(context))),
          );
        } else {
          context
              .read<ChatProvider>()
              .deleteConversationForUser(conversation.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conversation deleted'.tr(context))),
          );
        }
      },
      child: InkWell(
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
          if (context.mounted) {
            context.read<ChatProvider>().loadConversations();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(otherUser, colors),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      otherUser.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lastMessagePreview(conversation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasUnread
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDateTime(conversation.lastMessageAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasUnread
                          ? AppColors.primary
                          : colors.onSurfaceVariant,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(height: 5),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${conversation.unreadCount}',
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

  Widget _buildAvatar(User otherUser, ColorScheme colors) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: colors.surfaceContainerHighest,
      backgroundImage: otherUser.avatar != null
          ? CachedNetworkImageProvider(otherUser.avatar!)
          : null,
      child: otherUser.avatar == null
          ? Icon(Icons.person, color: colors.onSurfaceVariant)
          : null,
    );
  }

  String _lastMessagePreview(Conversation conversation) {
    final msg = conversation.lastMessage;
    if (msg == null) return '';
    switch (msg.mediaType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎵 Voice message';
      case 'document':
        return '📄 Document';
      default:
        return msg.displayContent;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return DateFormat('d MMM').format(local);
    return DateFormat.Md().format(local);
  }
}
