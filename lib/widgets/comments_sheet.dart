import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rooverse/models/moderation_result.dart';
import 'package:rooverse/services/ai_detection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../providers/feed_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/comment_repository.dart';
import '../services/kyc_verification_service.dart';
import '../services/supabase_service.dart';
import 'comment_card.dart';
import 'mention_autocomplete_field.dart';
import '../providers/platform_config_provider.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
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
  RealtimeChannel? _commentsChannel;

  File? _selectedMediaFile;
  String? _selectedMediaType; // 'image' or 'video'
  bool _isLoading = true;
  bool _isUploading = false;
  List<Comment>? _loadedComments;
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToCommentUpdates();
    _commentController.addListener(_onCommentTextChanged);
  }

  void _subscribeToCommentUpdates() {
    _commentsChannel = SupabaseService().client
        .channel('comments_sheet:${widget.post.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.commentsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: widget.post.id,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            final status = record['status'] as String?;
            if (status != 'published' && status != 'approved') return;
            if (!mounted) return;
            final feedProvider = context.read<FeedProvider>();
            await feedProvider.loadCommentsForPost(widget.post.id);
            final updated = await feedProvider.fetchCommentsForPost(widget.post.id);
            if (!mounted) return;
            setState(() => _loadedComments = updated);
          },
        )
        .subscribe();
  }

  void _onCommentTextChanged() {
    _textModerationTimer?.cancel();
    _textModerationTimer = Timer(const Duration(milliseconds: 1500), () {
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
    final feedProvider = context.read<FeedProvider>();
    await feedProvider.loadCommentsForPost(widget.post.id);

    if (mounted) {
      // loadCommentsForPost already stored results in the post's commentList.
      // Use that directly; fall back to a fresh fetch only for posts that are
      // not in the feed (e.g. opened from profile grid).
      final post = feedProvider.posts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );
      final comments = post.commentList ??
          await feedProvider.fetchCommentsForPost(widget.post.id);

      setState(() {
        _loadedComments = comments;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentTextChanged);
    _textModerationTimer?.cancel();
    if (_commentsChannel != null) {
      SupabaseService().client.removeChannel(_commentsChannel!);
    }
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
          imageQuality: 90,
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
        ).showSnackBar(SnackBar(content: Text('Failed to pick media. Please try again.'.tr(context))));
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
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Content Warning'.tr(context)),
              ],
            ),
            content: Text('Our AI detected potentially harmful content in your ${type}: ${res.details ?? "violation detected"}.\n\n'
              'If you post this, it may be hidden or your account could be flagged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('I Understand'.tr(context)),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearSelectedMedia();
                },
                child: Text('Remove Media'.tr(context)),
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

  // Instagram-style: find the top-level comment that owns this reply (for flat threading)
  String _getTopLevelParentId(String commentId, List<Comment> comments) {
    for (final comment in comments) {
      if (comment.id == commentId) return comment.id;
      if (_existsInReplies(commentId, comment.replies)) return comment.id;
    }
    return commentId;
  }

  bool _existsInReplies(String id, List<Comment>? replies) {
    if (replies == null) return false;
    for (final reply in replies) {
      if (reply.id == id) return true;
      if (_existsInReplies(id, reply.replies)) return true;
    }
    return false;
  }

  void _startReply(Comment comment) {
    final mentionPrefix = '@${comment.author.username} ';
    setState(() {
      _replyingTo = comment;
      _commentController.text = mentionPrefix;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: mentionPrefix.length),
      );
    });
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _commentController.clear();
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) {
      return;
    }

    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    // Capture and clear reply state before async work
    final replyParent = _replyingTo;

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
        ).showSnackBar(SnackBar(content: Text('Failed to upload media'.tr(context))));
        return;
      }
    }

    final commentText = _commentController.text.trim().isEmpty
        ? (mediaType == 'video' ? '📹 Video' : '📷 Photo')
        : _commentController.text.trim();

    if (replyParent != null) {
      // --- Posting a reply ---
      // Instagram-style: always reply to the top-level comment so threads stay flat
      final feedProvider = context.read<FeedProvider>();
      final currentPost = feedProvider.posts.firstWhere(
        (p) => p.id == widget.post.id,
        orElse: () => widget.post,
      );
      final currentComments = currentPost.commentList ?? _loadedComments ?? [];
      final topLevelParentId = _getTopLevelParentId(replyParent.id, currentComments);

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
        text: commentText,
        timestamp: 'Just now',
        likes: 0,
        isLiked: false,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

      feedProvider.addReplyLocally(
        widget.post.id,
        topLevelParentId,
        reply,
      );

      _commentController.clear();
      _clearSelectedMedia();
      setState(() {
        _replyingTo = null;
        _isUploading = false;
      });
      FocusScope.of(context).unfocus();

      try {
        await feedProvider.addReplyWithMedia(
          widget.post.id,
          topLevelParentId,
          commentText,
          tempId,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          onAiCheckComplete: (outcome) {
            if (!mounted) return;
            if (outcome == 'blocked') {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Your reply was not published. Our AI detected it may violate our guidelines.',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
            } else if (outcome == 'under_review') {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Your reply is under review. It will appear once approved.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 5),
                  ),
                );
            }
          },
        );
      } on KycNotVerifiedException catch (e) {
        await _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
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
      } on NotActivatedException catch (e) {
        await _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Buy ROO',
                  textColor: Colors.white,
                  onPressed: () {
                    if (context.mounted) {
                      Navigator.pushNamed(context, '/wallet');
                    }
                  },
                ),
              ),
            );
        }
      }
      return;
    }

    // --- Posting a top-level comment ---
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
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Comment under review.'.tr(context)),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    // Also save to Supabase and update with real ID
    Comment? savedComment;
    try {
      savedComment = await context.read<FeedProvider>().addCommentWithMedia(
        widget.post.id,
        commentText,
        tempId: tempId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        onAiCheckComplete: (outcome) {
          if (!mounted) return;
          if (outcome == 'blocked') {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Your comment was not published. Our AI detected it may violate our guidelines.'.tr(context),
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
          } else if (outcome == 'under_review') {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Your comment is under review. It will appear once approved.'.tr(context),
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
          }
        },
      );
      if (savedComment == null) {
        // Backend write failed: rollback optimistic UI and notify user.
        await _loadComments();
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Failed to post comment'.tr(context)),
                backgroundColor: Colors.red,
              ),
            );
        }
        return;
      }
    } on KycNotVerifiedException catch (e) {
      // Reload comments to clear the optimistic update
      await _loadComments();
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
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
    } on NotActivatedException catch (e) {
      // Reload comments to clear the optimistic update
      await _loadComments();
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Buy ROO',
                textColor: Colors.white,
                onPressed: () {
                  if (context.mounted) {
                    Navigator.pushNamed(context, '/wallet');
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
              SizedBox(height: 20),
              Text('Add Media'.tr(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library, color: colors.primary),
                ),
                title: Text('Photo from Gallery'.tr(context)),
                subtitle: Text('Choose an existing photo'.tr(context)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery);
                },
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: colors.secondary),
                ),
                title: Text('Take a Photo'.tr(context)),
                subtitle: Text('Use your camera'.tr(context)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera);
                },
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.videocam, color: colors.tertiary),
                ),
                title: Text('Video from Gallery'.tr(context)),
                subtitle: Text('Choose an existing video'.tr(context)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, isVideo: true);
                },
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fiber_manual_record, color: colors.error),
                ),
                title: Text('Record Video'.tr(context)),
                subtitle: Text('Record with your camera'.tr(context)),
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
                Text('Comments'.tr(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Spacer(),
                Consumer<FeedProvider>(
                  builder: (context, feedProvider, _) {
                    final currentPost = feedProvider.posts.firstWhere(
                      (p) => p.id == widget.post.id,
                      orElse: () => widget.post,
                    );
                    return Text(
                      '${currentPost.comments}'.tr(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    );
                  },
                ),
                SizedBox(width: 16),
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
                final comments = currentPost.commentList ?? _loadedComments;

                if (_isLoading) {
                  return Center(child: CircularProgressIndicator());
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
                        SizedBox(height: 16),
                        Text('No comments yet'.tr(context),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Be the first to comment!'.tr(context),
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
                      onReplyTap: _startReply,
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
                // Replying-to banner
                if (_replyingTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Replying to ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '@${_replyingTo!.author.username}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                                  child: Center(
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
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedMediaType == 'video')
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Text('Video selected'.tr(context),
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
                              ? Icon(Icons.person, size: 16)
                              : null,
                        );
                      },
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MentionAutocompleteField(
                            controller: _commentController,
                            focusNode: _commentFocus,
                            maxLength: context.watch<PlatformConfigProvider>().config.maxCommentLength,
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
                              child: Text('⚠️ Potential policy violation: ${_textModerationResult!.details ?? "Check content"}'.tr(context),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (_isModeratingText)
                            Padding(
                              padding: EdgeInsets.only(top: 4, left: 8),
                              child: Text('Checking safety...'.tr(context),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
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
