import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import 'package:swipe_to/swipe_to.dart';
import '../profile/profile_screen.dart';

class ConversationThreadPage extends StatefulWidget {
  final Conversation conversation;

  const ConversationThreadPage({super.key, required this.conversation});

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription? _profileSubscription;
  late User _otherUser;
  Message? _replyMessage;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  int _previousMessageCount = 0;
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id ?? '';
    _otherUser = widget.conversation.otherParticipant(currentUserId);

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // Real-time online/offline status listener
    _profileSubscription = SupabaseService().client
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

    // Scroll to bottom when messages first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    // Periodically update online/offline status (every 10 seconds)
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild to recalculate online status
        });
      }
    });

    // Mark as read on entry if there are unread messages
    if (widget.conversation.unreadCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatProvider>().markAsRead(widget.conversation.id);
      });
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _recordingTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<ChatProvider>().sendMessage(
      widget.conversation.id,
      text,
      replyToId: _replyMessage?.id,
      replyContent: _replyMessage?.content,
    );

    setState(() {
      _controller.clear();
      _replyMessage = null;
    });

    // Scroll to bottom after sending
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null && mounted) {
        context.read<ChatProvider>().sendMediaMessage(
          widget.conversation.id,
          image.path,
          image.name,
          'image',
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null && mounted) {
        String fileName = result.files.single.name;
        context.read<ChatProvider>().sendMessage(
          widget.conversation.id,
          '📄 Sent a document: $fileName',
        );
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _toggleAudioRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _recordingTimer?.cancel();
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
        });
        if (path != null && mounted) {
          context.read<ChatProvider>().sendMediaMessage(
            widget.conversation.id,
            path,
            'voice_message.m4a',
            'audio',
          );
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = path.join(
            directory.path,
            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );

          await _audioRecorder.start(const RecordConfig(), path: filePath);

          setState(() {
            _isRecording = true;
            _recordingDuration = 0;
          });

          _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            setState(() => _recordingDuration++);
          });
        }
      }
    } catch (e) {
      debugPrint('Error with audio recording: $e');
    }
  }

  void _showContactPicker() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Share Contact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          // Mocking some users to share
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Support Team'),
            onTap: () {
              context.read<ChatProvider>().sendMessage(
                widget.conversation.id,
                'Support Team',
                type: 'contact',
              );
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Community Moderator'),
            onTap: () {
              context.read<ChatProvider>().sendMessage(
                widget.conversation.id,
                'Community Moderator',
                type: 'contact',
              );
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('AI Assistant'),
            onTap: () {
              context.read<ChatProvider>().sendMessage(
                widget.conversation.id,
                'AI Assistant',
                type: 'contact',
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAttachmentSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.description,
                  label: 'Document',
                  color: const Color(0xFF7F66FF),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: const Color(0xFFFF2E74),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.photo,
                  label: 'Gallery',
                  color: const Color(0xFFC059FF),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.headset,
                  label: 'Audio',
                  color: const Color(0xFFFF7B2A),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleAudioRecording();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  color: const Color(0xFF00D261),
                  onTap: () async {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.person,
                  label: 'Contact',
                  color: const Color(0xFF00A5F4),
                  onTap: () {
                    Navigator.pop(context);
                    _showContactPicker();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        context.read<ChatProvider>().sendMessage(
          widget.conversation.id,
          '📍 My location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}',
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _showInfo(User otherUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: otherUser.avatar != null
                  ? NetworkImage(otherUser.avatar!)
                  : null,
              child: otherUser.avatar == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              otherUser.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '@${otherUser.username}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Encryption: Messages and calls are end-to-end encrypted. Tap to verify.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMenu(Message message) {
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
              context.read<ChatProvider>().deleteMessage(message.id);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _startCall(bool isVideo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVideo ? 'Video Call' : 'Voice Call'),
        content: const Text(
          'Calling feature integration (WebRTC/Agora) is in progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id ?? '';

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
              child: StreamBuilder<List<Message>>(
                stream: context.read<ChatProvider>().getMessageStream(
                  widget.conversation.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  // Auto-scroll to bottom when new messages arrive
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

                  // Mark messages as read when they arrive and we are viewing them
                  final unreadIncoming = messages.any(
                    (m) => !m.isRead && m.senderId != currentUserId,
                  );

                  if (unreadIncoming) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<ChatProvider>().markAsRead(
                        widget.conversation.id,
                      );
                    });
                  }

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

                      // Check for date header
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
                          SwipeTo(
                            onRightSwipe: (details) {
                              setState(() => _replyMessage = message);
                            },
                            child: GestureDetector(
                              onLongPress: () => _showDeleteMenu(message),
                              child: _MessageBubble(
                                message: message,
                                isMe: isMe,
                                otherUserAvatar: _otherUser.avatar,
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
    // Online logic: if lastSeen is within the last 2 minutes
    final now = DateTime.now();
    final isOnline =
        otherUser.lastSeen != null &&
        now.difference(otherUser.lastSeen!).inMinutes < 2;

    String statusText = isOnline ? 'Online' : 'Offline';
    if (!isOnline && otherUser.lastSeen != null) {
      final lastSeen = otherUser.lastSeen!;
      final difference = now.difference(lastSeen);

      if (difference.inDays == 0) {
        // Today - show time
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
              tag: 'avatar_${otherUser.id}',
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
        IconButton(
          onPressed: () => _startCall(true),
          icon: const Icon(Icons.videocam_outlined),
          color: colors.primary,
        ),
        IconButton(
          onPressed: () => _showInfo(otherUser),
          icon: const Icon(Icons.info_outline),
          color: colors.primary,
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
            'Start a conversation with ${otherUser.displayName}',
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Replying to',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        _replyMessage!.content,
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
              if (!_isRecording)
                IconButton(
                  onPressed: _showAttachmentSheet,
                  icon: const Icon(Icons.add_circle_outline),
                  color: colors.primary,
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isRecording
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.mic,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text('Recording message...'),
                                    ),
                                  ],
                                ),
                              )
                            : TextField(
                                controller: _controller,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  hintText: 'Message...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                      ),
                      if (!_isRecording)
                        IconButton(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          color: colors.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _controller.text.isEmpty
                  ? IconButton.filled(
                      onPressed: _toggleAudioRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic_none_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isRecording
                            ? Colors.red
                            : colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                    )
                  : IconButton.filled(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? otherUserAvatar;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.otherUserAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // WhatsApp-inspired colors
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    final textColor = isMe
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyToId != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest.withOpacity(
                                0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                left: BorderSide(color: Colors.blue, width: 4),
                              ),
                            ),
                            child: Text(
                              message.replyContent ?? 'Original message',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (message.messageType == 'image' &&
                            message.mediaUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: message.mediaUrl!,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: colors.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (message.messageType == 'audio' &&
                            message.mediaUrl != null)
                          _AudioPlayer(url: message.mediaUrl!, isMe: isMe),
                        if (message.messageType == 'contact')
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colors.primary,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.content,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Contact Info',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (message.messageType == 'text' ||
                            (message.content != '[Media]' &&
                                message.messageType != 'audio' &&
                                message.messageType != 'contact'))
                          Text(
                            message.content,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.Hm().format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done_all,
                            size: 15,
                            color: message.isRead
                                ? Colors.blue
                                : (isDark ? Colors.white38 : Colors.black26),
                          ),
                        ],
                      ],
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

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPlayer extends StatefulWidget {
  final String url;
  final bool isMe;

  const _AudioPlayer({required this.url, required this.isMe});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      final duration = await _player.setUrl(widget.url);
      if (mounted) setState(() => _duration = duration ?? Duration.zero);

      _positionSubscription = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _playerStateSubscription = _player.playerStateStream.listen((s) {
        if (mounted) {
          setState(() {
            _isPlaying = s.playing;
            if (s.processingState == ProcessingState.completed) {
              _player.seek(Duration.zero);
              _player.pause();
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = widget.isMe ? Colors.white : Colors.black87;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          color: widget.isMe ? Colors.white : colors.primary,
          onPressed: () => _isPlaying ? _player.pause() : _player.play(),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10,
                  ),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _duration.inMilliseconds.toDouble(),
                  onChanged: (v) =>
                      _player.seek(Duration(milliseconds: v.toInt())),
                  activeColor: widget.isMe ? Colors.white : colors.primary,
                  inactiveColor: (widget.isMe ? Colors.white : colors.primary)
                      .withOpacity(0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    return '${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}
