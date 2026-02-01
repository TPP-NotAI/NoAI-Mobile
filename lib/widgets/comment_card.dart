import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../utils/time_utils.dart';
import 'video_player_widget.dart';
import 'full_screen_media_viewer.dart';
import 'mention_rich_text.dart';

class CommentCard extends StatefulWidget {
  final Comment comment;
  final String postId;
  final bool isReply;
  final VoidCallback? onReplyTap;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postId,
    this.isReply = false,
    this.onReplyTap,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _showReplies = false;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  // Helper method to find the latest comment data from provider
  Comment? _findComment(
    FeedProvider provider,
    String postId,
    String commentId,
  ) {
    final post = provider.posts.firstWhere(
      (p) => p.id == postId,
      orElse: () => provider.posts.first,
    );

    if (post.commentList == null) return null;

    return _findCommentRecursive(post.commentList!, commentId);
  }

  Comment? _findCommentRecursive(List<Comment> comments, String commentId) {
    for (final comment in comments) {
      if (comment.id == commentId) {
        return comment;
      }
      if (comment.replies != null && comment.replies!.isNotEmpty) {
        final found = _findCommentRecursive(comment.replies!, commentId);
        if (found != null) return found;
      }
    }
    return null;
  }

  bool _isAuthor(Comment comment) {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || comment.authorId == null) return false;
    return currentUser.id == comment.authorId;
  }

  void _startEditing(Comment comment) {
    setState(() {
      _isEditing = true;
      _editController.text = comment.text;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(String commentId) async {
    final newText = _editController.text.trim();
    if (newText.isEmpty) return;

    final provider = context.read<FeedProvider>();
    final success = await provider.updateComment(
      widget.postId,
      commentId,
      newText,
    );

    if (mounted) {
      setState(() => _isEditing = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update comment')),
        );
      }
    }
  }

  Future<void> _confirmDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text(
          'Are you sure you want to delete this comment? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<FeedProvider>();
      final success = await provider.deleteComment(widget.postId, commentId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = context.watch<FeedProvider>();

    // Get the latest comment data from provider
    final currentComment =
        _findComment(provider, widget.postId, widget.comment.id) ??
        widget.comment;
    final hasReplies =
        currentComment.replies != null && currentComment.replies!.isNotEmpty;
    final replyCount = currentComment.replies?.length ?? 0;
    final isAuthor = _isAuthor(currentComment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment content
        Padding(
          padding: EdgeInsets.only(
            left: widget.isReply ? 48 : 16,
            right: 16,
            top: 12,
            bottom: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: ClipOval(
                  child: currentComment.author.avatar != null
                      ? Image.network(
                          currentComment.author.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: colors.surfaceVariant,
                              child: Icon(
                                Icons.person,
                                color: colors.onSurfaceVariant,
                                size: 16,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: colors.surfaceVariant,
                          child: Icon(
                            Icons.person,
                            color: colors.onSurfaceVariant,
                            size: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Comment details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author, timestamp, and more options
                    Row(
                      children: [
                        Text(
                          currentComment.author.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            humanReadableTime(currentComment.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        // More options menu (only for comment author)
                        if (isAuthor)
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: Icon(
                                Icons.more_horiz,
                                color: colors.onSurfaceVariant,
                                size: 16,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _startEditing(currentComment);
                                } else if (value == 'delete') {
                                  _confirmDelete(currentComment.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: colors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: colors.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Inline edit field or comment text
                    if (_isEditing)
                      _buildEditField(currentComment.id, colors, theme)
                    else ...[
                      // Comment text
                      if (currentComment.text.isNotEmpty &&
                          currentComment.text != '📷 Photo' &&
                          currentComment.text != '📹 Video')
                        MentionRichText(
                          text: currentComment.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                            height: 1.4,
                          ),
                          onMentionTap: (username) =>
                              navigateToMentionedUser(context, username),
                        ),

                      // Media attachment
                      if (currentComment.mediaUrl != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        FullScreenMediaViewer(
                                          mediaUrl: currentComment.mediaUrl!,
                                          isVideo:
                                              currentComment.mediaType ==
                                              'video',
                                          heroTag: '',
                                          post: provider.posts.firstWhere(
                                            (post) => post.id == widget.postId,
                                          ), // Pass the correct Post object
                                        ),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: currentComment.mediaType == 'video'
                                ? Container(
                                    height: 150,
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        VideoPlayerWidget(
                                          videoUrl: currentComment.mediaUrl!,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: Image.network(
                                      currentComment.mediaUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          height: 150,
                                          color: colors.surfaceContainerHighest,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              height: 150,
                                              color: colors
                                                  .surfaceContainerHighest,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),

                    // Actions
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: () {
                            context.read<FeedProvider>().toggleCommentLike(
                              widget.postId,
                              currentComment.id,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentComment.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 14,
                                  color: currentComment.isLiked
                                      ? colors.error
                                      : colors.onSurfaceVariant,
                                ),
                                if (currentComment.likes > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentComment.likes}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: currentComment.isLiked
                                          ? colors.error
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Reply button
                        InkWell(
                          onTap: widget.onReplyTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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

        // Show/hide replies button (only for top-level comments with replies)
        if (!widget.isReply && hasReplies)
          Padding(
            padding: const EdgeInsets.only(left: 60, bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _showReplies = !_showReplies),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showReplies ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showReplies
                          ? 'Hide replies'
                          : 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Nested replies (collapsible for top-level, always shown for nested)
        if (hasReplies && (widget.isReply || _showReplies))
          ...currentComment.replies!.map(
            (reply) => CommentCard(
              comment: reply,
              postId: widget.postId,
              isReply: true,
              onReplyTap: widget.onReplyTap,
            ),
          ),
      ],
    );
  }

  Widget _buildEditField(
    String commentId,
    ColorScheme colors,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _editController,
          autofocus: true,
          maxLines: null,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: FilledButton(
                onPressed: () => _saveEdit(commentId),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  'Save',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
