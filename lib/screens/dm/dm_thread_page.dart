import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/dm_service.dart';
import '../../providers/dm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/dm_thread.dart';
import '../../models/dm_message.dart';
import '../../models/user.dart';
import '../profile/profile_screen.dart';

class DmThreadPage extends StatefulWidget {
  final DmThread thread;

  const DmThreadPage({super.key, required this.thread});

  @override
  State<DmThreadPage> createState() => _DmThreadPageState();
}

class _DmThreadPageState extends State<DmThreadPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _profileSubscription;
  late User _otherUser;
  int _previousMessageCount = 0;
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();

    final currentUserId =
        context.read<AuthProvider>().currentUser?.id ?? '';
    _otherUser = widget.thread.otherParticipant(currentUserId);

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // Real-time online/offline status listener
    _profileSubscription = SupabaseService()
        .client
        .from('profiles')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', _otherUser.id)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            setState(() {
              _otherUser = User.fromSupabase(data.first);
            });
          }
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _statusUpdateTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<DmProvider>().sendMessage(widget.thread.id, text);

    setState(() => _controller.clear());

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showDeleteMenu(DmMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete for me',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              context.read<DmProvider>().deleteMessage(message.id);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentUserId =
        context.read<AuthProvider>().currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: _buildAppBar(context, _otherUser, colors),
      body: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          image: DecorationImage(
            image: const NetworkImage(
              'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
            ),
            opacity: theme.brightness == Brightness.dark ? 0.05 : 0.08,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<DmMessage>>(
                stream: context.read<DmProvider>().getMessageStream(
                      widget.thread.id,
                    ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  final hasNewMessages =
                      messages.length > _previousMessageCount;
                  if (hasNewMessages && _scrollController.hasClients) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  }
                  _previousMessageCount = messages.length;

                  if (messages.isEmpty) {
                    return _buildEmptyState(colors, _otherUser);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;

                      bool showDate = false;
                      if (index == messages.length - 1) {
                        showDate = true;
                      } else {
                        final nextMessage = messages[index + 1];
                        if (message.createdAt.day !=
                            nextMessage.createdAt.day) {
                          showDate = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDate)
                            _buildDateHeader(message.createdAt, colors),
                          GestureDetector(
                            onLongPress: () => _showDeleteMenu(message),
                            child: _DmBubble(
                              message: message,
                              isMe: isMe,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(context, colors),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    User otherUser,
    ColorScheme colors,
  ) {
    final now = DateTime.now();
    final isOnline = otherUser.lastSeen != null &&
        now.difference(otherUser.lastSeen!).inMinutes < 2;

    String statusText = isOnline ? 'Online' : 'Offline';
    if (!isOnline && otherUser.lastSeen != null) {
      final lastSeen = otherUser.lastSeen!;
      final difference = now.difference(lastSeen);

      if (difference.inDays == 0) {
        statusText = 'Last seen ${DateFormat.Hm().format(lastSeen)}';
      } else if (difference.inDays == 1) {
        statusText = 'Last seen yesterday';
      } else if (difference.inDays < 7) {
        statusText = 'Last seen ${difference.inDays} days ago';
      } else {
        statusText = 'Last seen ${DateFormat.MMMd().format(lastSeen)}';
      }
    } else if (otherUser.lastSeen == null) {
      statusText = 'Offline';
    }

    return AppBar(
      elevation: 0,
      backgroundColor: colors.surface.withOpacity(0.8),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant.withOpacity(0.3)),
          ),
        ),
      ),
      leadingWidth: 40,
      title: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfileScreen(userId: otherUser.id, showAppBar: true),
            ),
          );
        },
        child: Row(
          children: [
            Hero(
              tag: 'dm_avatar_${otherUser.id}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary.withOpacity(0.1),
                backgroundImage: otherUser.avatar != null
                    ? CachedNetworkImageProvider(otherUser.avatar!)
                    : null,
                child: otherUser.avatar == null
                    ? Icon(Icons.person, size: 20, color: colors.primary)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherUser.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: colors.onSurface),
          onSelected: (value) async {
            if (value == 'mute') {
              final isMuted = await DmService().isMuted(widget.thread.id);
              if (context.mounted) {
                await context
                    .read<DmProvider>()
                    .toggleMute(widget.thread.id, !isMuted);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isMuted ? 'Unmuted' : 'Muted'),
                    ),
                  );
                }
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mute',
              child: Text('Toggle mute'),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colors, User otherUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colors.primary.withOpacity(0.05),
            backgroundImage: otherUser.avatar != null
                ? CachedNetworkImageProvider(otherUser.avatar!)
                : null,
            child: otherUser.avatar == null
                ? Icon(Icons.person, size: 40, color: colors.primary)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a DM with ${otherUser.displayName}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messages are encrypted and secure',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _getFriendlyDate(date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  String _getFriendlyDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildInputArea(BuildContext context, ColorScheme colors) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _controller.text.isEmpty ? null : _sendMessage,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMe;

  const _DmBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    final textColor = isMe
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 4),
          Flexible(
            child: Container(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: 4,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 40),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      DateFormat.Hm().format(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
