import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comment.dart';
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
                    // Author and timestamp
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
                        Text(
                          humanReadableTime(currentComment.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

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
                                isVideo: currentComment.mediaType == 'video',
                                heroTag: '',
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                    opacity: animation, child: child);
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
                                          color: Colors.black.withValues(alpha: 0.5),
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
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 150,
                                        color: colors.surfaceContainerHighest,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
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
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 150,
                                        color: colors.surfaceContainerHighest,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
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
}
