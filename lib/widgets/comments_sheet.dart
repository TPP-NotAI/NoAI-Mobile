import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rooverse/models/moderation_result.dart';
import 'package:rooverse/services/ai_detection_service.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../providers/feed_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/comment_repository.dart';
import '../services/kyc_verification_service.dart';
import 'comment_card.dart';
import 'mention_autocomplete_field.dart';

class CommentsSheet extends StatefulWidget {
  final Post post;

  const CommentsSheet({super.key, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final CommentRepository _commentRepo = CommentRepository();
  final AiDetectionService _aiDetectionService = AiDetectionService();

  // Real-time moderation state
  Timer? _textModerationTimer;
  bool _isModeratingText = false;
  ModerationResult? _textModerationResult;

  File? _selectedMediaFile;
  String? _selectedMediaType; // 'image' or 'video'
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentController.addListener(_onCommentTextChanged);
  }

  void _onCommentTextChanged() {
    _textModerationTimer?.cancel();
    _textModerationTimer = Timer(const Duration(milliseconds: 800), () {
      _moderateText();
    });
  }

  Future<void> _moderateText() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _textModerationResult = null);
      return;
    }

    if (mounted) setState(() => _isModeratingText = true);

    try {
      final res = await _aiDetectionService.moderateText(text);
      if (mounted) {
        setState(() {
          _textModerationResult = res;
          _isModeratingText = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isModeratingText = false);
    }
  }

  Future<void> _loadComments() async {
    await context.read<FeedProvider>().loadCommentsForPost(widget.post.id);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentTextChanged);
    _textModerationTimer?.cancel();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      XFile? file;
      if (isVideo) {
        file = await _imagePicker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
      } else {
        file = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920,
        );
      }

      if (file != null && mounted) {
        final mediaFile = File(file.path);

        // Proactive moderation
        _moderateMedia(mediaFile, isVideo ? 'video' : 'image');

        setState(() {
          _selectedMediaFile = mediaFile;
          _selectedMediaType = isVideo ? 'video' : 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick media: $e')));
      }
    }
  }

  Future<void> _moderateMedia(File file, String type) async {
    try {
      final res = type == 'image'
          ? await _aiDetectionService.moderateImage(file)
          : await _aiDetectionService.moderateVideo(file);

      if (res != null && res.flagged) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Content Warning'),
              ],
            ),
            content: Text(
              'Our AI detected potentially harmful content in your ${type}: ${res.details ?? "violation detected"}.\n\n'
              'If you post this, it may be hidden or your account could be flagged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I Understand'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearSelectedMedia();
                },
                child: const Text('Remove Media'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Proactive moderation failed: $e');
    }
  }

  void _clearSelectedMedia() {
    setState(() {
      _selectedMediaFile = null;
      _selectedMediaType = null;
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty && _selectedMediaFile == null) {
      return;
    }

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    String? mediaUrl;
    String? mediaType;

    // Upload media if selected
    if (_selectedMediaFile != null) {
      mediaUrl = await _commentRepo.uploadCommentMedia(
        file: _selectedMediaFile!,
        userId: user.id,
      );
      mediaType = _selectedMediaType;

      if (mediaUrl == null && mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to upload media')));
        return;
      }
    }

    final commentText = _commentController.text.trim().isEmpty
        ? (mediaType == 'video' ? '📹 Video' : '📷 Photo')
        : _commentController.text.trim();

    final tempId = 'c${DateTime.now().millisecondsSinceEpoch}';
    final newComment = Comment(
      id: tempId,
      authorId: user.id,
      author: CommentAuthor(
        displayName: user.displayName,
        username: user.username,
        isVerified: user.isVerified,
        avatar: user.avatar,
      ),
      text: commentText,
      timestamp: 'Just now',
      likes: 0,
      isLiked: false,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );

    context.read<FeedProvider>().addCommentLocally(widget.post.id, newComment);
    // Also save to Supabase and update with real ID
    try {
      await context.read<FeedProvider>().addCommentWithMedia(
        widget.post.id,
        commentText,
        tempId: tempId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
    } on KycNotVerifiedException catch (e) {
      // Reload comments to clear the optimistic update
      await context.read<FeedProvider>().loadCommentsForPost(widget.post.id);
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Verify',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/verify');
                  }
                },
              ),
            ),
          );
      }
      return;
    }

    _commentController.clear();
    _clearSelectedMedia();
    setState(() => _isUploading = false);
    FocusScope.of(context).unfocus();
  }

  void _showMediaPickerOptions() {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Media',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: colors.primary),
                ),
                title: const Text('Photo from Gallery'),
                subtitle: const Text('Choose an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: colors.secondary),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Use your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.videocam, color: colors.tertiary),
                ),
                title: const Text('Video from Gallery'),
                subtitle: const Text('Choose an existing video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, isVideo: true);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fiber_manual_record, color: colors.error),
                ),
                title: const Text('Record Video'),
                subtitle: const Text('Record with your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, isVideo: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplySheet(Comment parentComment) {
    final replyController = TextEditingController();
    File? replyMediaFile;
    String? replyMediaType;
    bool isReplyUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            Future<void> pickReplyMedia(
              ImageSource source, {
              bool isVideo = false,
            }) async {
              try {
                XFile? file;
                if (isVideo) {
                  file = await _imagePicker.pickVideo(
                    source: source,
                    maxDuration: const Duration(minutes: 2),
                  );
                } else {
                  file = await _imagePicker.pickImage(
                    source: source,
                    imageQuality: 80,
                    maxWidth: 1920,
                    maxHeight: 1920,
                  );
                }

                if (file != null) {
                  setSheetState(() {
                    replyMediaFile = File(file!.path);
                    replyMediaType = isVideo ? 'video' : 'image';
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to pick media: $e')),
                  );
                }
              }
            }

            Future<void> submitReply() async {
              if (replyController.text.trim().isEmpty &&
                  replyMediaFile == null) {
                return;
              }

              final user = context.read<UserProvider>().currentUser;
              if (user == null) return;

              setSheetState(() => isReplyUploading = true);

              String? mediaUrl;
              String? mediaType;

              // Upload media if selected
              if (replyMediaFile != null) {
                mediaUrl = await _commentRepo.uploadCommentMedia(
                  file: replyMediaFile!,
                  userId: user.id,
                );
                mediaType = replyMediaType;

                if (mediaUrl == null) {
                  setSheetState(() => isReplyUploading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to upload media')),
                    );
                  }
                  return;
                }
              }

              final replyText = replyController.text.trim().isEmpty
                  ? (mediaType == 'video' ? '📹 Video' : '📷 Photo')
                  : replyController.text.trim();

              final tempId = 'r${DateTime.now().millisecondsSinceEpoch}';
              final reply = Comment(
                id: tempId,
                authorId: user.id,
                author: CommentAuthor(
                  displayName: user.displayName,
                  username: user.username,
                  isVerified: user.isVerified,
                  avatar: user.avatar,
                ),
                text: replyText,
                timestamp: 'Just now',
                likes: 0,
                isLiked: false,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
              );

              context.read<FeedProvider>().addReplyLocally(
                widget.post.id,
                parentComment.id,
                reply,
              );
              // Also save to Supabase and update with real ID
              try {
                await context.read<FeedProvider>().addReplyWithMedia(
                  widget.post.id,
                  parentComment.id,
                  replyText,
                  tempId,
                  mediaUrl: mediaUrl,
                  mediaType: mediaType,
                );
              } on KycNotVerifiedException catch (e) {
                // Reload comments to clear the optimistic update
                await context.read<FeedProvider>().loadCommentsForPost(
                  widget.post.id,
                );
                if (mounted) {
                  setSheetState(() => isReplyUploading = false);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: Colors.orange,
                        action: SnackBarAction(
                          label: 'Verify',
                          textColor: Colors.white,
                          onPressed: () {
                            if (context.mounted) {
                              Navigator.pushNamed(context, '/verify');
                            }
                          },
                        ),
                      ),
                    );
                }
                return;
              }

              Navigator.pop(context);
              setState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Reply to',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colors.onSurfaceVariant,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Parent comment preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  parentComment.author.avatar != null
                                  ? NetworkImage(parentComment.author.avatar!)
                                  : null,
                              child: parentComment.author.avatar == null
                                  ? Icon(
                                      Icons.person,
                                      color: colors.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parentComment.author.displayName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    parentComment.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Media preview for reply
                      if (replyMediaFile != null) ...[
                        Container(
                          height: 120,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: replyMediaType == 'video'
                                    ? Container(
                                        width: double.infinity,
                                        color: Colors.black,
                                        child: const Center(
                                          child: Icon(
                                            Icons.videocam,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                      )
                                    : Image.file(
                                        replyMediaFile!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setSheetState(() {
                                    replyMediaFile = null;
                                    replyMediaType = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              if (replyMediaType == 'video')
                                const Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Text(
                                    'Video selected',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // Reply input with media button
                      Row(
                        children: [
                          Expanded(
                            child: MentionAutocompleteField(
                              controller: replyController,
                              autofocus: true,
                              maxLines: 3,
                              minLines: 1,
                              style: TextStyle(color: colors.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Write your reply...',
                                hintStyle: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                                filled: true,
                                fillColor: colors.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: colors.outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: colors.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (ctx) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: Icon(
                                            Icons.photo_library,
                                            color: colors.primary,
                                          ),
                                          title: const Text(
                                            'Photo from Gallery',
                                          ),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            pickReplyMedia(ImageSource.gallery);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(
                                            Icons.camera_alt,
                                            color: colors.secondary,
                                          ),
                                          title: const Text('Take a Photo'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            pickReplyMedia(ImageSource.camera);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(
                                            Icons.videocam,
                                            color: colors.tertiary,
                                          ),
                                          title: const Text('Video'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            pickReplyMedia(
                                              ImageSource.gallery,
                                              isVideo: true,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.image_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reply button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isReplyUploading ? null : submitReply,
                          child: isReplyUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Reply'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.post.comments}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Consumer<FeedProvider>(
              builder: (context, feedProvider, _) {
                // Get the current post from provider to get updated comments
                final currentPost = feedProvider.posts.firstWhere(
                  (p) => p.id == widget.post.id,
                  orElse: () => widget.post,
                );
                final comments = currentPost.commentList;

                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (comments == null || comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return CommentCard(
                      comment: comment,
                      postId: widget.post.id,
                      onReplyTap: () => _showReplySheet(comment),
                    );
                  },
                );
              },
            ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: (MediaQuery.of(context).viewInsets.bottom > 0)
                  ? MediaQuery.of(context).viewInsets.bottom + 12
                  : MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Media preview
                if (_selectedMediaFile != null) ...[
                  Container(
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _selectedMediaType == 'video'
                              ? Container(
                                  width: double.infinity,
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  _selectedMediaFile!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _clearSelectedMedia,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedMediaType == 'video')
                          const Positioned(
                            bottom: 8,
                            left: 8,
                            child: Text(
                              'Video selected',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        final user = userProvider.currentUser;
                        return CircleAvatar(
                          radius: 16,
                          backgroundImage: user?.avatar != null
                              ? NetworkImage(user!.avatar!)
                              : null,
                          child: user?.avatar == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MentionAutocompleteField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            style: TextStyle(color: colors.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(
                                color: colors.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: colors.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _addComment(),
                          ),
                          if (_textModerationResult != null &&
                              _textModerationResult!.flagged)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 8),
                              child: Text(
                                '⚠️ Potential policy violation: ${_textModerationResult!.details ?? "Check content"}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (_isModeratingText)
                            const Padding(
                              padding: EdgeInsets.only(top: 4, left: 8),
                              child: Text(
                                'Checking safety...',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isUploading ? null : _showMediaPickerOptions,
                      icon: Icon(
                        Icons.image_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      onPressed: _isUploading ? null : _addComment,
                      icon: _isUploading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(Icons.send, color: colors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
