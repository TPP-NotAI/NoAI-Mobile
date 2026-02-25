import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import '../../services/supabase_service.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/story_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import 'package:swipe_to/swipe_to.dart';
import '../profile/profile_screen.dart';
import '../../widgets/story_viewer.dart';
import '../../widgets/video_player_widget.dart';
import '../../utils/verification_utils.dart';
import '../../utils/snackbar_utils.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class ConversationThreadPage extends StatefulWidget {
  final Conversation conversation;

  const ConversationThreadPage({super.key, required this.conversation});

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _profileSubscription;
  StreamSubscription? _readReceiptSubscription;
  late User _otherUser;
  Message? _replyMessage;
  int _previousMessageCount = 0;
  Timer? _statusUpdateTimer;
  bool _isSendingMedia = false;
  DateTime? _otherUserLastReadAt;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Reactions: messageId → Map<emoji, List<userId>>
  final Map<String, Map<String, List<String>>> _reactions = {};

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

    // Subscribe to the other user's last_read_at for real-time read receipts.
    // Supabase stream() with a composite PK only supports .eq() on one column,
    // so we filter by thread_id and match user_id client-side.
    _readReceiptSubscription = SupabaseService().client
        .from('dm_participants')
        .stream(primaryKey: ['thread_id', 'user_id'])
        .eq('thread_id', widget.conversation.id)
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
              _otherUserLastReadAt = raw != null
                  ? DateTime.tryParse(raw)
                  : null;
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
    _readReceiptSubscription?.cancel();
    _statusUpdateTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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

    final isActivated = await VerificationUtils.checkActivation(context);
    if (!mounted || !isActivated) return;

    setState(() => _isSendingMedia = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      final fileName = path.split('/').last;
      await chatProvider.sendMediaMessage(
        widget.conversation.id,
        path,
        fileName,
        'audio',
        onAdFeeRequired: _showAdFeeDialog,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e'.tr(context))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
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
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', currentUserId)
            .eq('emoji', emoji);
      } else {
        await client.from('message_reactions').upsert({
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

  void _showReactionPicker(BuildContext ctx, Message message) {
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Require full activation (verified + purchased ROO) to send messages
    final isActivated = await VerificationUtils.checkActivation(context);
    if (!mounted || !isActivated) return;

    FocusScope.of(context).unfocus();
    final chatProvider = context.read<ChatProvider>();

    try {
      await chatProvider.sendMessage(
        widget.conversation.id,
        text,
        replyToId: _replyMessage?.id,
        replyContent: _replyMessage?.content,
        onAdFeeRequired: _showAdFeeDialog,
      );

      if (!mounted) return;
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
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showErrorMessage(
        context,
        chatProvider.error ?? 'Failed to send message. Please try again.',
      );
    }
  }

  Future<void> _openStoryReference(Message message) async {
    final storyId = message.storyReferenceId;
    if (storyId == null) return;

    final storyProvider = context.read<StoryProvider>();
    if (storyProvider.stories.isEmpty && !storyProvider.isLoading) {
      await storyProvider.loadStories();
    }
    if (!mounted) return;

    final allStories = storyProvider.stories;
    if (allStories.isEmpty) {
      SnackBarUtils.showInfo(context, 'Story is no longer available.');
      return;
    }

    final storyIndex = allStories.indexWhere((story) => story.id == storyId);
    if (storyIndex == -1) {
      SnackBarUtils.showInfo(context, 'Story has expired or is unavailable.');
      return;
    }

    final targetStory = allStories[storyIndex];
    final userStories =
        allStories.where((story) => story.userId == targetStory.userId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final initialIndex = userStories.indexWhere((story) => story.id == storyId);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewer(
          stories: List.of(userStories),
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null && mounted) {
        await _previewAndSendMedia(image.path, image.name, 'image');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
          'csv',
        ],
      );
      if (result != null && result.files.single.path != null && mounted) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        await _previewAndSendMedia(filePath, fileName, 'document');
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && mounted) {
        final sizeBytes = result.files.single.size;
        if (sizeBytes > 100 * 1024 * 1024) {
          SnackBarUtils.showWarning(
            context,
            'Video too large. Max size is 100MB.',
          );
          return;
        }
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        await _previewAndSendMedia(filePath, fileName, 'video');
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  /// Shows a preview bottom sheet for the selected media.
  /// Only sends when the user taps the Send button.
  Future<void> _previewAndSendMedia(
    String filePath,
    String fileName,
    String type,
  ) async {
    if (!mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MediaPreviewSheet(
        filePath: filePath,
        fileName: fileName,
        type: type,
      ),
    );

    if (confirmed == true && mounted) {
      await _sendMediaAttachment(filePath, fileName, type);
    }
  }

  Future<void> _sendMediaAttachment(
    String filePath,
    String fileName,
    String type,
  ) async {
    if (_isSendingMedia || !mounted) return;
    setState(() => _isSendingMedia = true);

    try {
      await context.read<ChatProvider>().sendMediaMessage(
        widget.conversation.id,
        filePath,
        fileName,
        type,
        onAdFeeRequired: _showAdFeeDialog,
      );
    } catch (_) {
      if (mounted) {
        final chatProvider = context.read<ChatProvider>();
        SnackBarUtils.showErrorMessage(
          context,
          chatProvider.error ?? 'Failed to send media. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMedia = false);
      }
    }
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
                  icon: Icons.videocam,
                  label: 'Video',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
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

  Future<void> _openMessageLink(String rawUrl) async {
    final normalized =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      SnackBarUtils.showErrorMessage(context, 'Could not open link');
    }
  }

  void _showInfo(User otherUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Info'.tr(context)),
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
            Text('@${otherUser.username}'.tr(context),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text('Encryption: Messages and calls are end-to-end encrypted. Tap to verify.'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  void _showDeleteMenu(Message message) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isMyMessage = message.senderId == currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.blue),
            title: Text('Delete for me'.tr(context)),
            onTap: () {
              context.read<ChatProvider>().deleteMessageForMe(message.id);
              Navigator.pop(context);
            },
          ),
          if (isMyMessage)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Delete for everyone'.tr(context),
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete for Everyone?'.tr(context)),
                    content: Text('This message will be permanently deleted for all participants.'.tr(context),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text(AppLocalizations.of(context)!.delete),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  context.read<ChatProvider>().deleteMessageForEveryone(
                    message.id,
                  );
                  Navigator.pop(context);
                }
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
        content: Text('Calling feature integration (WebRTC/Agora) is in progress.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'.tr(context)),
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
                                allMessages: messages,
                                otherUserAvatar: _otherUser.avatar,
                                otherUserLastReadAt: _otherUserLastReadAt,
                                onLinkTap: _openMessageLink,
                                onStoryTap: message.hasStoryReference
                                    ? () => _openStoryReference(message)
                                    : null,
                                reactions: _reactions[message.id] ?? {},
                                currentUserId: currentUserId,
                                onReactionTap: (emoji) =>
                                    _toggleReaction(message.id, emoji),
                                onReactionPickerTap: () =>
                                    _showReactionPicker(context, message),
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
        now.difference(otherUser.lastSeen!).inMinutes < 5;

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

    final isSupportChat =
        otherUser.username.toLowerCase().contains('support') ||
        otherUser.username.toLowerCase().contains('admin') ||
        otherUser.displayName == 'Support Team';

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
      title: GestureDetector(
        onTap: isSupportChat
            ? null
            : () {
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
                backgroundImage: !isSupportChat && otherUser.avatar != null
                    ? CachedNetworkImageProvider(otherUser.avatar!)
                    : null,
                child: isSupportChat
                    ? Icon(Icons.headset_mic, size: 20, color: colors.primary)
                    : otherUser.avatar == null
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
                    isSupportChat
                        ? 'Support Team'
                        : otherUser.displayName.isNotEmpty
                        ? otherUser.displayName
                        : otherUser.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSupportChat)
                    Text('Official Support'.tr(context),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
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
          Text('Start a conversation with ${otherUser.displayName}'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text('Messages are encrypted and secure'.tr(context),
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
                const SizedBox(width: 8),
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
                        _replyMessage!.displayContent,
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
              IconButton(
                onPressed: _isSendingMedia ? null : _showAttachmentSheet,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isSendingMedia
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
          const SizedBox(width: 8),
          const Icon(Icons.mic, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const Spacer(),
          Text('Release to send'.tr(context),
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(width: 12),
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
          'content_type': 'message',
          'conversation_id': widget.conversation.id,
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
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? otherUserAvatar;
  final VoidCallback? onStoryTap;
  final Future<void> Function(String url)? onLinkTap;
  final List<Message> allMessages;
  final DateTime? otherUserLastReadAt;
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final void Function(String emoji) onReactionTap;
  final VoidCallback onReactionPickerTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.allMessages,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    required this.onReactionPickerTap,
    this.otherUserAvatar,
    this.onStoryTap,
    this.onLinkTap,
    this.otherUserLastReadAt,
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
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyToId != null) ...[
                              () {
                                final replied = allMessages.firstWhere(
                                  (m) => m.id == message.replyToId,
                                  orElse: () => message,
                                );
                                final replyText =
                                    replied.id == message.replyToId
                                        ? replied.displayContent.isNotEmpty
                                              ? replied.displayContent
                                              : replied.mediaType == 'image'
                                              ? '📷 Photo'
                                              : replied.mediaType == 'video'
                                              ? '🎥 Video'
                                              : replied.mediaType == 'audio'
                                              ? '🎵 Voice message'
                                              : 'Attachment'
                                        : 'Original message';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: const Border(
                                      left: BorderSide(
                                        color: Colors.blue,
                                        width: 4,
                                      ),
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
                              }(),
                            ],
                            if (message.hasStoryReference && onStoryTap != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: onStoryTap,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_stories_outlined,
                                          size: 16,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text('View Story'.tr(context),
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (message.messageType == 'image' &&
                                message.mediaUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _FullscreenImagePage(
                                        url: message.mediaUrl!,
                                      ),
                                    ),
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.65,
                                      minWidth: 120,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: message.mediaUrl!,
                                        placeholder: (context, url) =>
                                            Container(
                                              height: 200,
                                              width: double.infinity,
                                              color:
                                                  colors.surfaceContainerHighest,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              height: 200,
                                              width: double.infinity,
                                              color:
                                                  colors.surfaceContainerHighest,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (message.messageType == 'audio' &&
                                message.mediaUrl != null)
                              _AudioPlayer(url: message.mediaUrl!, isMe: isMe),
                            if (message.messageType == 'video' &&
                                message.mediaUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.65,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: VideoPlayerWidget(
                                      videoUrl: message.mediaUrl!,
                                    ),
                                  ),
                                ),
                              ),
                            if (message.messageType == 'document' &&
                                message.mediaUrl != null)
                              GestureDetector(
                                onTap: () async {
                                  final uri = Uri.tryParse(message.mediaUrl!);
                                  if (uri == null) return;
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file_outlined,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          message.displayContent,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: textColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (message.messageType == 'text' &&
                                message.displayContent.trim().isNotEmpty)
                              _LinkifiedMessageText(
                                text: message.displayContent,
                                textColor: textColor,
                                linkColor: isMe ? Colors.white : colors.primary,
                                onLinkTap: onLinkTap ?? (_) async {},
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
                            if (message.aiScore != null ||
                                message.aiScoreStatus != null) ...[
                              _AiScoreBadge(
                                score: message.aiScore,
                                status: message.aiScoreStatus,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              DateFormat.Hm().format(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              if (message.status == 'sending')
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black26,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.done_all,
                                  size: 15,
                                  color:
                                      (otherUserLastReadAt != null &&
                                          !message.createdAt.isAfter(
                                            otherUserLastReadAt!,
                                          ))
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
                ),
              ),
              if (isMe) const SizedBox(width: 4),
            ],
          ),
          // Reaction chips row
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isMe ? 0 : 8,
                right: isMe ? 8 : 0,
              ),
              child: Wrap(
                spacing: 4,
                children: [
                  ...reactions.entries.map((entry) {
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
                        child: Text('${emoji} ${users.length}'.tr(context),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: onReactionPickerTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add_reaction_outlined,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ───────────────── FULLSCREEN IMAGE ───────────────── */

class _FullscreenImagePage extends StatelessWidget {
  final String url;
  const _FullscreenImagePage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkifiedMessageText extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color linkColor;
  final Future<void> Function(String url) onLinkTap;

  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/|www\.)[^\s]+)',
    caseSensitive: false,
  );

  const _LinkifiedMessageText({
    required this.text,
    required this.textColor,
    required this.linkColor,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(color: textColor, fontSize: 15, height: 1.3);
    final linkStyle = defaultStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final link = text.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: link,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              onLinkTap(link);
            },
        ),
      );

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: defaultStyle, children: spans),
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
    final maxMs = _duration.inMilliseconds.toDouble();
    final safeMaxMs = maxMs <= 0 ? 1.0 : maxMs;
    final safeValue = _position.inMilliseconds.toDouble().clamp(0.0, safeMaxMs);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          color: widget.isMe ? Colors.white : colors.primary,
          onPressed: maxMs <= 0
              ? null
              : () => _isPlaying ? _player.pause() : _player.play(),
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
                  value: safeValue,
                  max: safeMaxMs,
                  onChanged: maxMs <= 0
                      ? null
                      : (v) => _player.seek(Duration(milliseconds: v.toInt())),
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

class _AiScoreBadge extends StatelessWidget {
  final double? score;
  final String? status;

  const _AiScoreBadge({required this.score, this.status});

  @override
  Widget build(BuildContext context) {
    if (score == null && status == null) return const SizedBox.shrink();

    final bool isFlagged =
        status == 'flagged' || (score != null && score! >= 75);
    final bool isReview =
        status == 'review' || (score != null && score! >= 50 && score! < 75);

    final Color badgeColor;
    final Color bgColor;
    final String label;

    if (isFlagged) {
      badgeColor = const Color(0xFFEF4444); // Red
      bgColor = const Color(0xFF2D0F0F);
      label = 'AI';
    } else if (isReview) {
      badgeColor = const Color(0xFFF59E0B); // Amber
      bgColor = const Color(0xFF451A03);
      label = 'REQ';
    } else {
      // Cleanest view for passed checks: just a green dot
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981), // Green
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that previews the selected media before the user confirms send.
class _MediaPreviewSheet extends StatelessWidget {
  final String filePath;
  final String fileName;
  final String type;

  const _MediaPreviewSheet({
    required this.filePath,
    required this.fileName,
    required this.type,
  });

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = File(filePath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Send ${type[0].toUpperCase()}${type.substring(1)}'.tr(context),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Preview area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: type == 'image'
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _FileIconPreview(
                          type: type,
                          fileName: fileName,
                          fileSize: fileSize,
                          colors: colors,
                        ),
                      ),
                    )
                  : _FileIconPreview(
                      type: type,
                      fileName: fileName,
                      fileSize: fileSize,
                      colors: colors,
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // File name + size row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatBytes(fileSize),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Cancel'.tr(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('Send'.tr(context)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileIconPreview extends StatelessWidget {
  final String type;
  final String fileName;
  final int fileSize;
  final ColorScheme colors;

  const _FileIconPreview({
    required this.type,
    required this.fileName,
    required this.fileSize,
    required this.colors,
  });

  IconData get _icon {
    switch (type) {
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _iconColor {
    switch (type) {
      case 'video':
        return const Color(0xFF8B5CF6);
      case 'audio':
        return const Color(0xFF00D261);
      case 'document':
        return const Color(0xFF7F66FF);
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 64, color: _iconColor),
          const SizedBox(height: 12),
          Text(
            fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
