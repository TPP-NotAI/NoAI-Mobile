import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../config/app_spacing.dart';
import '../config/app_typography.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../services/kyc_verification_service.dart';
import '../utils/responsive_extensions.dart';
import '../utils/time_utils.dart';
import 'video_player_widget.dart';
import 'full_screen_media_viewer.dart';
import 'mention_rich_text.dart';
import 'report_sheet.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
class CommentCard extends StatefulWidget {
  final Comment comment;
  final String postId;
  final bool isReply;
  final int depth;
  final ValueChanged<Comment>? onReplyTap;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postId,
    this.isReply = false,
    this.depth = 0,
    this.onReplyTap,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _showReplies = false;
  bool _isEditing = false;
  int _visibleRepliesCount = 3;
  late TextEditingController _editController;
  Comment? _commentOverride;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant CommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _commentOverride = null;
    }
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
    final postIndex = provider.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return null;
    final post = provider.posts[postIndex];

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

  void _applyLocalLikeToggle(Comment comment) {
    final nextIsLiked = !comment.isLiked;
    final nextLikes = nextIsLiked
        ? comment.likes + 1
        : (comment.likes - 1).clamp(0, 1 << 30);
    setState(() {
      _commentOverride = comment.copyWith(
        isLiked: nextIsLiked,
        likes: nextLikes,
      );
    });
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
          SnackBar(content: Text('Failed to update comment'.tr(context))),
        );
      }
    }
  }

  Future<void> _confirmDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Comment'.tr(context)),
        content: Text('Are you sure you want to delete this comment? This cannot be undone.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<FeedProvider>();
      final success = await provider.deleteComment(widget.postId, commentId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment'.tr(context))),
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
    final providerComment = _findComment(provider, widget.postId, widget.comment.id);
    final localOverride = _commentOverride;
    final currentComment = localOverride != null
        ? (providerComment ?? widget.comment).copyWith(
            isLiked: localOverride.isLiked,
            likes: localOverride.likes,
          )
        : (providerComment ?? widget.comment);
    final hasReplies =
        currentComment.replies != null && currentComment.replies!.isNotEmpty;
    final canRenderNestedReplies = widget.depth < 3;
    final replyCount = currentComment.replies?.length ?? 0;
    final replies = currentComment.replies ?? const <Comment>[];
    final showReplies = hasReplies && _showReplies && canRenderNestedReplies;
    final displayedReplies = showReplies
        ? replies.take(_visibleRepliesCount).toList()
        : const <Comment>[];
    final remainingReplies = replies.length - displayedReplies.length;
    final isAuthor = _isAuthor(currentComment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment content
        Padding(
          padding: EdgeInsets.only(
            left: widget.depth > 0
                ? (widget.depth * 40.0).responsive(context, min: widget.depth * 32.0, max: widget.depth * 48.0)
                : AppSpacing.medium.responsive(context),
            right: AppSpacing.medium.responsive(context),
            top: AppSpacing.standard.responsive(context),
            bottom: AppSpacing.mediumSmall.responsive(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 32.responsive(context, min: 28, max: 36),
                height: 32.responsive(context, min: 28, max: 36),
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
                                size: AppTypography.responsiveIconSize(
                                  context,
                                  16,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: colors.surfaceVariant,
                          child: Icon(
                            Icons.person,
                            color: colors.onSurfaceVariant,
                            size: AppTypography.responsiveIconSize(context, 16),
                          ),
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.standard.responsive(context)),

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
                        SizedBox(
                          width: AppSpacing.mediumSmall.responsive(context),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                humanReadableTime(currentComment.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: AppTypography.responsiveFontSize(
                                    context,
                                    AppTypography.extraSmall,
                                  ),
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(
                                width: AppSpacing.mediumSmall.responsive(
                                  context,
                                ),
                              ),
                              Flexible(
                                child: _AiCheckBadge(
                                  aiScore: currentComment.aiScore,
                                  aiScoreStatus: currentComment.aiScoreStatus,
                                  commentStatus: currentComment.status,
                                  colors: colors,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // More options menu
                        SizedBox(
                          width: 28.responsive(context, min: 24, max: 32),
                          height: 28.responsive(context, min: 24, max: 32),
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: AppTypography.responsiveIconSize(
                              context,
                              16,
                            ),
                            icon: Icon(
                              Icons.more_horiz,
                              color: colors.onSurfaceVariant,
                              size: AppTypography.responsiveIconSize(
                                context,
                                16,
                              ),
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _startEditing(currentComment);
                              } else if (value == 'delete') {
                                _confirmDelete(currentComment.id);
                              } else if (value == 'report') {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (_) => ReportSheet(
                                    reportType: 'comment',
                                    referenceId: currentComment.id,
                                    reportedUserId:
                                        currentComment.authorId ?? '',
                                    username: currentComment.author.username,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              if (isAuthor) ...[
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: AppTypography.responsiveIconSize(
                                          context,
                                          18,
                                        ),
                                      ),
                                      SizedBox(
                                        width: AppSpacing.mediumSmall
                                            .responsive(context),
                                      ),
                                      Text('Edit'.tr(context)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: AppTypography.responsiveIconSize(
                                          context,
                                          18,
                                        ),
                                        color: colors.error,
                                      ),
                                      SizedBox(
                                        width: AppSpacing.mediumSmall
                                            .responsive(context),
                                      ),
                                      Text(
                                        'Delete'.tr(context),
                                        style: TextStyle(color: colors.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else
                                PopupMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        size: AppTypography.responsiveIconSize(
                                          context,
                                          18,
                                        ),
                                        color: colors.error,
                                      ),
                                      SizedBox(
                                        width: AppSpacing.mediumSmall
                                            .responsive(context),
                                      ),
                                      Text(
                                        'Report'.tr(context),
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
                    SizedBox(height: AppSpacing.extraSmall.responsive(context)),

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
                        SizedBox(
                          height: AppSpacing.mediumSmall.responsive(context),
                        ),
                        GestureDetector(
                          onTap: () {
                            final postIndex = provider.posts.indexWhere(
                              (post) => post.id == widget.postId,
                            );
                            if (postIndex == -1) return;
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
                                          post: provider.posts[postIndex],
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
                            borderRadius: AppSpacing.responsiveRadius(
                              context,
                              AppSpacing.radiusLarge,
                            ),
                            child: currentComment.mediaType == 'video'
                                ? Container(
                                    height: 150.responsive(
                                      context,
                                      min: 130,
                                      max: 170,
                                    ),
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        VideoPlayerWidget(
                                          videoUrl: currentComment.mediaUrl!,
                                        ),
                                        Container(
                                          padding: EdgeInsets.all(
                                            AppSpacing.mediumSmall.responsive(
                                              context,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size:
                                                AppTypography.responsiveIconSize(
                                                  context,
                                                  30,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 200.responsive(
                                        context,
                                        min: 170,
                                        max: 230,
                                      ),
                                    ),
                                    child: Image.network(
                                      currentComment.mediaUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          height: 150.responsive(
                                            context,
                                            min: 130,
                                            max: 170,
                                          ),
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
                                              height: 150.responsive(
                                                context,
                                                min: 130,
                                                max: 170,
                                              ),
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
                    SizedBox(
                      height: AppSpacing.mediumSmall.responsive(context),
                    ),

                    // Actions
                    Row(
                      children: [
                        // Like button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              try {
                                final feedProvider = context.read<FeedProvider>();
                                if (mounted) {
                                  _applyLocalLikeToggle(currentComment);
                                }

                                await feedProvider.toggleCommentLike(
                                  widget.postId,
                                  currentComment.id,
                                );
                              } on KycNotVerifiedException catch (e) {
                                if (mounted) {
                                  _applyLocalLikeToggle(currentComment);
                                }
                                if (context.mounted) {
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
                                              Navigator.pushNamed(
                                                context,
                                                '/verify',
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                }
                              } on NotActivatedException catch (e) {
                                if (mounted) {
                                  _applyLocalLikeToggle(currentComment);
                                }
                                if (context.mounted) {
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
                                              Navigator.pushNamed(
                                                context,
                                                '/wallet',
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                }
                              }
                            },
                            borderRadius: AppSpacing.responsiveRadius(
                              context,
                              AppSpacing.radiusLarge,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.mediumSmall.responsive(
                                  context,
                                ),
                                vertical: AppSpacing.extraSmall.responsive(
                                  context,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    currentComment.isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: AppTypography.responsiveIconSize(
                                      context,
                                      14,
                                    ),
                                    color: currentComment.isLiked
                                        ? colors.error
                                        : colors.onSurfaceVariant,
                                  ),
                                  if (currentComment.likes > 0) ...[
                                    SizedBox(
                                      width: AppSpacing.extraSmall.responsive(
                                        context,
                                      ),
                                    ),
                                    Text('${currentComment.likes}'.tr(context),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontSize:
                                                AppTypography.responsiveFontSize(
                                                  context,
                                                  AppTypography.badgeText,
                                                ),
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
                        ),
                        SizedBox(
                          width: AppSpacing.largePlus.responsive(context),
                        ),

                        // Reply button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onReplyTap == null
                                ? null
                                : () => widget.onReplyTap!(currentComment),
                            borderRadius: AppSpacing.responsiveRadius(
                              context,
                              AppSpacing.radiusLarge,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.mediumSmall.responsive(
                                  context,
                                ),
                                vertical: AppSpacing.extraSmall.responsive(
                                  context,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: AppTypography.responsiveIconSize(
                                      context,
                                      14,
                                    ),
                                    color: colors.onSurfaceVariant,
                                  ),
                                  SizedBox(
                                    width: AppSpacing.extraSmall.responsive(
                                      context,
                                    ),
                                  ),
                                  Text('Reply'.tr(context),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                            AppTypography.badgeText,
                                          ),
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
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

        // Show/hide replies button
        if (canRenderNestedReplies && hasReplies)
          Padding(
            padding: EdgeInsets.only(
              left: ((widget.depth + 1) * 40.0 + 20).responsive(context,
                  min: (widget.depth + 1) * 32.0 + 16,
                  max: (widget.depth + 1) * 48.0 + 20),
              bottom: AppSpacing.mediumSmall.responsive(context),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() {
                  if (_showReplies) {
                    _showReplies = false;
                    _visibleRepliesCount = 3;
                  } else {
                    _showReplies = true;
                  }
                }),
                borderRadius: AppSpacing.responsiveRadius(
                  context,
                  AppSpacing.radiusSmall,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.mediumSmall.responsive(context),
                    vertical: AppSpacing.extraSmall.responsive(context),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showReplies ? Icons.expand_less : Icons.expand_more,
                        size: AppTypography.responsiveIconSize(context, 16),
                        color: colors.primary,
                      ),
                      SizedBox(
                        width: AppSpacing.extraSmall.responsive(context),
                      ),
                      Text(
                        _showReplies
                            ? 'Hide replies'
                            : 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: AppTypography.responsiveFontSize(
                            context,
                            AppTypography.badgeText,
                          ),
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (showReplies && remainingReplies > 0)
          Padding(
            padding: EdgeInsets.only(
              left: ((widget.depth + 1) * 40.0 + 20).responsive(context,
                  min: (widget.depth + 1) * 32.0 + 16,
                  max: (widget.depth + 1) * 48.0 + 20),
              bottom: AppSpacing.mediumSmall.responsive(context),
            ),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _visibleRepliesCount += 3;
                });
              },
              child: Text('View previous replies ($remainingReplies)'.tr(context),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ),
          ),

        // Nested replies (Instagram-style: top-level comment can expand one reply level)
        if (showReplies)
          ...displayedReplies.map(
            (reply) => CommentCard(
              comment: reply,
              postId: widget.postId,
              isReply: true,
              depth: widget.depth + 1,
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.standard.responsive(context),
              vertical: AppSpacing.mediumSmall.responsive(context),
            ),
            border: OutlineInputBorder(
              borderRadius: AppSpacing.responsiveRadius(
                context,
                AppSpacing.radiusSmall,
              ),
              borderSide: BorderSide(color: colors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.responsiveRadius(
                context,
                AppSpacing.radiusSmall,
              ),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.mediumSmall.responsive(context)),
        Row(
          children: [
            SizedBox(
              height: 30.responsive(context, min: 26, max: 34),
              child: TextButton(
                onPressed: _cancelEditing,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.standard.responsive(context),
                  ),
                ),
                child: Text('Cancel'.tr(context),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.badgeText,
                    ),
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.mediumSmall.responsive(context)),
            SizedBox(
              height: 30.responsive(context, min: 26, max: 34),
              child: FilledButton(
                onPressed: () => _saveEdit(commentId),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.standard.responsive(context),
                  ),
                ),
                child: Text('Save'.tr(context),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      AppTypography.badgeText,
                    ),
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

class _AiCheckBadge extends StatelessWidget {
  final double? aiScore;
  final String? aiScoreStatus;
  final String? commentStatus;
  final ColorScheme colors;

  const _AiCheckBadge({
    required this.aiScore,
    required this.aiScoreStatus,
    required this.commentStatus,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedAiStatus = aiScoreStatus?.toLowerCase();
    final normalizedCommentStatus = commentStatus?.toLowerCase();
    final bool forcePending = normalizedCommentStatus == 'under_review' &&
        normalizedAiStatus != 'review' &&
        normalizedAiStatus != 'flagged';
    final bool needsReview =
        normalizedAiStatus == 'review' ||
        normalizedAiStatus == 'flagged' ||
        normalizedCommentStatus == 'deleted';
    final bool isPassed =
        normalizedAiStatus == 'pass' ||
        (!forcePending &&
            normalizedCommentStatus == 'published' &&
            aiScore != null &&
            aiScore! < 50);

    late final Color badgeColor;
    late final Color bgColor;
    late final String label;

    if (needsReview) {
      badgeColor = colors.error;
      bgColor = colors.errorContainer.withValues(alpha: 0.2);
      label = 'AI CHECK: REVIEW';
    } else if (isPassed) {
      badgeColor = const Color(0xFF10B981); // Green
      bgColor = const Color(0xFF052E1C);
      label = 'AI CHECK: PASSED';
    } else {
      badgeColor = colors.onSurfaceVariant;
      bgColor = colors.surfaceContainerHighest.withValues(alpha: 0.6);
      label = 'AI CHECK: PENDING';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.mediumSmall.responsive(context),
        vertical: AppSpacing.extraSmall.responsive(context),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusSmall,
        ),
        border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.responsive(context, min: 5, max: 7),
            height: 6.responsive(context, min: 5, max: 7),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpacing.small.responsive(context)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(context, 10),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}


