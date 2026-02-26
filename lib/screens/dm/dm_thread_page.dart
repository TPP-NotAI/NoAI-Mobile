import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/dm_service.dart';
import '../../providers/dm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/dm_thread.dart';
import '../../models/dm_message.dart';
import '../../models/user.dart';
import '../profile/profile_screen.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
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
  StreamSubscription? _readReceiptSubscription;
  StreamSubscription? _typingSubscription;
  late User _otherUser;
  int _previousMessageCount = 0;
  Timer? _statusUpdateTimer;
  Timer? _typingTimer;
  DateTime? _otherUserLastReadAt;
  DmMessage? _replyMessage;
  bool _isOtherUserTyping = false;
  bool _isSending = false;
  String? _sendError;

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Reactions: messageId → Map<emoji, List<userId>>
  final Map<String, Map<String, List<String>>> _reactions = {};

  @override
  void initState() {
    super.initState();

    final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';
    _otherUser = widget.thread.otherParticipant(currentUserId);

    _controller.addListener(_onTypingChanged);

    // Real-time profile/online status listener
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

    // Real-time read receipt: watch dm_participants for the other user's last_read_at
    _readReceiptSubscription = SupabaseService()
        .client
        .from('dm_participants')
        .stream(primaryKey: ['thread_id', 'user_id'])
        .eq('thread_id', widget.thread.id)
        .listen((data) {
          if (!mounted) return;
          final rows = data.cast<Map<String, dynamic>>();
          final row = rows.firstWhere(
            (r) => r['user_id'] == _otherUser.id,
            orElse: () => {},
          );
          if (row.isNotEmpty) {
            final raw = row['last_read_at'] as String?;
            setState(() {
              _otherUserLastReadAt =
                  raw != null ? DateTime.tryParse(raw) : null;
            });
          }
        });

    // Real-time typing indicator: watch dm_typing for the other user
    _typingSubscription = SupabaseService()
        .client
        .from('dm_typing')
        .stream(primaryKey: ['thread_id', 'user_id'])
        .eq('thread_id', widget.thread.id)
        .listen((data) {
          if (!mounted) return;
          final rows = data.cast<Map<String, dynamic>>();
          final otherTyping = rows.any((r) {
            if (r['user_id'] != _otherUser.id) return false;
            final updatedAt = r['updated_at'] as String?;
            if (updatedAt == null) return false;
            final t = DateTime.tryParse(updatedAt);
            if (t == null) return false;
            return DateTime.now().difference(t).inSeconds < 5;
          });
          setState(() => _isOtherUserTyping = otherTyping);
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });

    // Mark thread as read on entry
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService().client
          .from('dm_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('thread_id', widget.thread.id)
          .eq('user_id', userId);
    } catch (_) {}
  }

  void _onTypingChanged() {
    if (mounted) setState(() {});
    _updateTypingPresence();
  }

  void _updateTypingPresence() {
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null) return;

    _typingTimer?.cancel();
    if (_controller.text.isNotEmpty) {
      SupabaseService().client.from('dm_typing').upsert({
        'thread_id': widget.thread.id,
        'user_id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'thread_id,user_id');

      // Auto-clear typing after 4 seconds of no keystrokes
      _typingTimer = Timer(const Duration(seconds: 4), _clearTypingPresence);
    } else {
      _clearTypingPresence();
    }
  }

  Future<void> _clearTypingPresence() async {
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService().client
          .from('dm_typing')
          .delete()
          .eq('thread_id', widget.thread.id)
          .eq('user_id', userId);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _clearTypingPresence();
    setState(() {
      _isSending = true;
      _sendError = null;
    });

    final replyId = _replyMessage?.id;
    final replyBody = _replyMessage?.body;

    try {
      final dmProvider = context.read<DmProvider>();
      await dmProvider.sendMessage(
        widget.thread.id,
        text,
        replyToId: replyId,
        replyContent: replyBody,
        onAdFeeRequired: _showAdFeeDialog,
      );

      if (!mounted) return;
      setState(() {
        _controller.clear();
        _replyMessage = null;
        _sendError = null;
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showDeleteMenu(DmMessage message, String currentUserId) {
    final isMe = message.senderId == currentUserId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_reaction_outlined, color: Colors.blue),
            title: Text('React'.tr(context)),
            onTap: () {
              Navigator.pop(ctx);
              _showReactionPicker(context, message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined, color: Colors.blue),
            title: Text('Copy text'.tr(context)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.body));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied to clipboard'.tr(context)),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.reply_outlined, color: Colors.blue),
            title: Text('Reply'.tr(context)),
            onTap: () {
              setState(() => _replyMessage = message);
              Navigator.pop(ctx);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete'.tr(context),
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                context.read<DmProvider>().deleteMessage(message.id);
                Navigator.pop(ctx);
              },
            ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clearTypingPresence();
    _profileSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _audioRecorder.dispose();
    _controller.removeListener(_onTypingChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission denied'.tr(context))),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/dm_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
    if (path == null || !mounted) return;

    setState(() => _isSending = true);
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) return;

      final storagePath = 'voice/$userId/$fileName';
      await SupabaseService().client.storage
          .from('dm-media')
          .uploadBinary(storagePath, bytes);

      final publicUrl = SupabaseService().client.storage
          .from('dm-media')
          .getPublicUrl(storagePath);

      await SupabaseService().client.from('dm_messages').insert({
        'thread_id': widget.thread.id,
        'sender_id': userId,
        'body': '[Voice message]',
        'media_url': publicUrl,
        'media_type': 'audio',
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendError = 'Failed to send voice message: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  // ─── Emoji reactions ───────────────────────────────────────────────────────

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final currentUserId =
        context.read<AuthProvider>().currentUser?.id ?? '';
    final client = SupabaseService().client;

    final existing = _reactions[messageId]?[emoji];
    final alreadyReacted = existing?.contains(currentUserId) ?? false;

    setState(() {
      _reactions.putIfAbsent(messageId, () => {});
      _reactions[messageId]!.putIfAbsent(emoji, () => []);
      if (alreadyReacted) {
        _reactions[messageId]![emoji]!.remove(currentUserId);
        if (_reactions[messageId]![emoji]!.isEmpty) {
          _reactions[messageId]!.remove(emoji);
        }
      } else {
        _reactions[messageId]![emoji]!.add(currentUserId);
      }
    });

    try {
      if (alreadyReacted) {
        await client
            .from('dm_message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', currentUserId)
            .eq('emoji', emoji);
      } else {
        await client.from('dm_message_reactions').upsert({
          'message_id': messageId,
          'user_id': currentUserId,
          'emoji': emoji,
        });
      }
    } catch (_) {
      // Revert optimistic update on failure
      setState(() {
        if (alreadyReacted) {
          _reactions[messageId]!.putIfAbsent(emoji, () => []);
          _reactions[messageId]![emoji]!.add(currentUserId);
        } else {
          _reactions[messageId]?[emoji]?.remove(currentUserId);
        }
      });
    }
  }

  void _showReactionPicker(BuildContext ctx, DmMessage message) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            Navigator.pop(ctx);
            _toggleReaction(message.id, emoji.emoji);
          },
          config: Config(
            height: 300,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
            ),
          ),
        ),
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
                    return Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  final hasNewMessages =
                      messages.length > _previousMessageCount;
                  if (hasNewMessages && _scrollController.hasClients) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    // Mark as read when new messages arrive
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _markAsRead());
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
                    itemCount: messages.length + (_isOtherUserTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Typing indicator is the first item (index 0 when reversed = top of list = bottom of screen)
                      if (_isOtherUserTyping && index == 0) {
                        return _TypingIndicator(otherUser: _otherUser);
                      }

                      final msgIndex =
                          _isOtherUserTyping ? index - 1 : index;
                      final message = messages[msgIndex];
                      final isMe = message.senderId == currentUserId;

                      // Date header logic
                      bool showDate = false;
                      if (msgIndex == messages.length - 1) {
                        showDate = true;
                      } else {
                        final nextMessage = messages[msgIndex + 1];
                        if (message.createdAt.toLocal().day != nextMessage.createdAt.toLocal().day) {
                          showDate = true;
                        }
                      }

                      // Message grouping: is this the last message in a consecutive run from same sender?
                      final isLastInGroup = msgIndex == 0 ||
                          messages[msgIndex - 1].senderId != message.senderId;

                      return Column(
                        children: [
                          if (showDate)
                            _buildDateHeader(message.createdAt.toLocal(), colors),
                          SwipeTo(
                            onRightSwipe: (_) {
                              setState(() => _replyMessage = message);
                            },
                            child: GestureDetector(
                              onLongPress: () =>
                                  _showDeleteMenu(message, currentUserId),
                              child: _DmBubble(
                                message: message,
                                isMe: isMe,
                                isLastInGroup: isLastInGroup,
                                otherUserAvatar: _otherUser.avatar,
                                otherUserLastReadAt: _otherUserLastReadAt,
                                replyMessages: messages,
                                reactions: _reactions[message.id] ?? {},
                                currentUserId: currentUserId,
                                onReactionTap: (emoji) =>
                                    _toggleReaction(message.id, emoji),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_sendError != null)
              Container(
                color: Colors.red.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sendError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _sendError = null),
                    ),
                  ],
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
        now.difference(otherUser.lastSeen!).inMinutes < 5;

    String statusText = isOnline ? 'Online' : 'Offline';
    if (!isOnline && otherUser.lastSeen != null) {
      final lastSeen = otherUser.lastSeen!;
      final difference = now.difference(lastSeen);

      final lastSeenLocal = lastSeen.toLocal();
      if (difference.inDays == 0) {
        statusText = 'Last seen ${DateFormat.Hm().format(lastSeenLocal)}';
      } else if (difference.inDays == 1) {
        statusText = 'Last seen yesterday';
      } else if (difference.inDays < 7) {
        statusText = 'Last seen ${difference.inDays} days ago';
      } else {
        statusText = 'Last seen ${DateFormat.MMMd().format(lastSeenLocal)}';
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
            bottom:
                BorderSide(color: colors.outlineVariant.withOpacity(0.3)),
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
            Stack(
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
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
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
                  Text(
                    _isOtherUserTyping ? 'typing...' : statusText,
                    style: TextStyle(
                      fontSize: 11,
                      color: _isOtherUserTyping
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontStyle: _isOtherUserTyping
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
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
            PopupMenuItem(
              value: 'mute',
              child: Text('Toggle mute'.tr(context)),
            ),
          ],
        ),
        SizedBox(width: 8),
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
          SizedBox(height: 16),
          Text('Start a DM with ${otherUser.displayName}'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          SizedBox(height: 8),
          Text('Messages are encrypted and secure'.tr(context),
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: ['Hey 👋', 'What\'s up?', 'Hi!'].map((q) {
              return ActionChip(
                label: Text(q),
                onPressed: () {
                  _controller.text = q;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: q.length),
                  );
                },
              );
            }).toList(),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return 'Today';
    } else if (local.day == now.day - 1 &&
        local.month == now.month &&
        local.year == now.year) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(local);
    }
  }

  Widget _buildInputArea(BuildContext context, ColorScheme colors) {
    if (_isRecording) {
      return _buildRecordingBar(colors);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colors.surfaceContainerHighest.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replying to'.tr(context),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        _replyMessage!.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _replyMessage = null),
                ),
              ],
            ),
          ),
        Container(
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
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.sentences,
                          enableSuggestions: true,
                          autocorrect: true,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              _isSending
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                    )
                  : _controller.text.isNotEmpty
                  ? IconButton.filled(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                    )
                  : GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopAndSendRecording(),
                      child: IconButton.filled(
                        onPressed: null,
                        icon: const Icon(Icons.mic),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          disabledBackgroundColor: colors.primary,
                          disabledForegroundColor: colors.onPrimary,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _showAdFeeDialog(double adConfidence, String? adType) async {
    const double adFeeRoo = 5.0;
    if (!mounted) return false;

    final walletProvider = context.read<WalletProvider>();
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign_outlined, color: Color(0xFFFF8C00)),
            const SizedBox(width: 8),
            Text('Advertisement Detected'.tr(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our system detected this message as promotional content '
              '(${adConfidence.toStringAsFixed(0)}% confidence'
              '${adType != null ? " - ${adType.replaceAll('_', ' ')}" : ""}).',
            ),
            const SizedBox(height: 12),
            Text(
              'To send it, an advertising fee is required.'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ad fee'.tr(context)),
                  Text(
                    '${adFeeRoo.toStringAsFixed(0)} ROO'.tr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'If you decline, the message will not be sent.'.tr(context),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now'.tr(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
            ),
            child: Text('Pay ${adFeeRoo.toStringAsFixed(0)} ROO'.tr(context)),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final success = await walletProvider.spendRoo(
        userId: userId,
        amount: adFeeRoo,
        activityType: 'AD_FEE',
        metadata: {
          'content_type': 'dm_message',
          'thread_id': widget.thread.id,
          'ad_confidence': adConfidence,
          'ad_type': adType,
        },
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient ROO balance to pay the advertising fee.'.tr(context),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return success;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Widget _buildRecordingBar(ColorScheme colors) {
    final mins = _recordingSeconds ~/ 60;
    final secs = _recordingSeconds % 60;
    final timeLabel =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          SizedBox(width: 8),
          const Icon(Icons.mic, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          Spacer(),
          Text('Release to send'.tr(context),
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(width: 12),
          IconButton.filled(
            onPressed: _stopAndSendRecording,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Typing indicator bubble (animated dots)
// ─────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  final User otherUser;

  const _TypingIndicator({required this.otherUser});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bubbleColor =
        isDark ? const Color(0xFF202C33) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colors.surfaceContainerHighest,
            backgroundImage: widget.otherUser.avatar != null
                ? CachedNetworkImageProvider(widget.otherUser.avatar!)
                : null,
            child: widget.otherUser.avatar == null
                ? Icon(Icons.person, size: 14, color: colors.onSurfaceVariant)
                : null,
          ),
          SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _animations[i],
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _animations[i].value),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DM Message Bubble
// ─────────────────────────────────────────────

class _DmBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMe;
  final bool isLastInGroup;
  final String? otherUserAvatar;
  final DateTime? otherUserLastReadAt;
  final List<DmMessage> replyMessages;
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final void Function(String emoji) onReactionTap;

  const _DmBubble({
    required this.message,
    required this.isMe,
    required this.isLastInGroup,
    required this.replyMessages,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    this.otherUserAvatar,
    this.otherUserLastReadAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    final textColor = isDark ? Colors.white : Colors.black87;

    // Determine read receipt state
    final isRead = otherUserLastReadAt != null &&
        !message.createdAt.isAfter(otherUserLastReadAt!);

    return Padding(
      padding: EdgeInsets.only(
        top: 1,
        bottom: isLastInGroup ? 6 : 1,
        left: 4,
        right: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          // Avatar shown only on last message in a group (non-me messages)
          if (!isMe) ...[
            if (isLastInGroup)
              CircleAvatar(
                radius: 12,
                backgroundColor: colors.surfaceContainerHighest,
                backgroundImage: otherUserAvatar != null
                    ? CachedNetworkImageProvider(otherUserAvatar!)
                    : null,
                child: otherUserAvatar == null
                    ? Icon(Icons.person, size: 14,
                        color: colors.onSurfaceVariant)
                    : null,
              )
            else
              SizedBox(width: 24),
            SizedBox(width: 6),
          ],
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
                  bottomLeft: Radius.circular(isMe ? 12 : (isLastInGroup ? 0 : 12)),
                  bottomRight: Radius.circular(isMe ? (isLastInGroup ? 0 : 12) : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Under-review badge
                  if (message.aiScoreStatus == 'review')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 12,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.orange.shade700,
                          ),
                          SizedBox(width: 4),
                          Text('Under review · Only you can see this'.tr(context),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.amber.shade300
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Reply preview
                  if (message.replyToId != null) ...[
                    _buildReplyPreview(colors, isDark),
                  ],
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, right: 52),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.Hm().format(message.createdAt.toLocal()),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                            if (isMe) ...[
                              SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 15,
                                color: isRead
                                    ? Colors.blue
                                    : (isDark
                                        ? Colors.white38
                                        : Colors.black26),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) SizedBox(width: 4),
            ],
          ),
          // Reaction chips
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isMe ? 0 : 42,
                right: isMe ? 8 : 0,
              ),
              child: Wrap(
                spacing: 4,
                children: reactions.entries.map((entry) {
                  final emoji = entry.key;
                  final users = entry.value;
                  final iMine = users.contains(currentUserId);
                  return GestureDetector(
                    onTap: () => onReactionTap(emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: iMine
                            ? colors.primary.withValues(alpha: 0.15)
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: iMine
                              ? colors.primary.withValues(alpha: 0.4)
                              : colors.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Text('$emoji ${users.length}'.tr(context),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ColorScheme colors, bool isDark) {
    final replied = replyMessages.firstWhere(
      (m) => m.id == message.replyToId,
      orElse: () => message,
    );
    final replyText = replied.id == message.replyToId
        ? replied.body
        : 'Original message';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Colors.blue, width: 3),
        ),
      ),
      child: Text(
        replyText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

}
