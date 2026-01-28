import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/report_sheet.dart';
import '../utils/time_utils.dart';
import 'create/edit_post_screen.dart';
import '../widgets/full_screen_media_viewer.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final String? heroTag;

  const PostDetailScreen({super.key, required this.post, this.heroTag});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  late TextEditingController _editController;
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _loadingComments = true;
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _editController = TextEditingController(text: _post.content);
    _loadComments();
  }

  @override
  void dispose() {
    _editController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final feedProvider = context.read<FeedProvider>();
    final comments = await feedProvider.fetchCommentsForPost(_post.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submittingComment = true);

    final feedProvider = context.read<FeedProvider>();
    final newComment = await feedProvider.addComment(_post.id, text);

    if (mounted) {
      setState(() => _submittingComment = false);
      if (newComment != null) {
        _commentController.clear();
        setState(() {
          _comments.add(newComment);
          _post = _post.copyWith(comments: _post.comments + 1);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment posted!')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to post comment')));
      }
    }
  }

  Future<void> _handleEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPostScreen(post: _post)),
    );

    if (mounted) {
      // Refresh local post state from provider
      final feedProvider = context.read<FeedProvider>();
      try {
        final updatedPost = feedProvider.posts.firstWhere(
          (p) => p.id == _post.id,
          orElse: () => _post,
        );
        setState(() {
          _post = updatedPost;
        });
      } catch (e) {
        debugPrint('Error refreshing post: $e');
      }
    }
  }

  void _handleUnpublish() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpublish Post?'),
        content: const Text(
          'This will remove the post from the public feed. You can republish it later (not implemented yet).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final feedProvider = context.read<FeedProvider>();
      final success = await feedProvider.unpublishPost(_post.id);
      if (success && mounted) {
        Navigator.pop(context); // Go back to feed/profile
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post unpublished')));
      }
    }
  }

  void _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final feedProvider = context.read<FeedProvider>();
      final success = await feedProvider.deletePost(_post.id);
      if (success && mounted) {
        Navigator.pop(context); // Go back
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final feedProvider = context.watch<FeedProvider>();
    final isAuthor = authProvider.currentUser?.id == _post.authorId;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          if (isAuthor)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _handleEdit();
                    break;
                  case 'unpublish':
                    _handleUnpublish();
                    break;
                  case 'delete':
                    _handleDelete();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Post'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'unpublish',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, size: 20),
                      SizedBox(width: 12),
                      Text('Unpublish'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: _post.author.avatar.isNotEmpty
                                    ? NetworkImage(_post.author.avatar)
                                    : null,
                                backgroundColor: colors.surfaceContainerHighest,
                                child: _post.author.avatar.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        color: colors.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _post.author.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      '@${_post.author.username}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                humanReadableTime(_post.timestamp),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _post.content,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 16),
                          if (_post.location != null &&
                              _post.location!.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _post.location!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_post.tags != null && _post.tags!.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _post.tags!.map((tag) {
                                return Text(
                                  '#${tag.tag}',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_post.primaryMediaUrl != null) ...[
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (
                                          context,
                                          animation,
                                          secondaryAnimation,
                                        ) => FullScreenMediaViewer(
                                          mediaUrl: _post.primaryMediaUrl!,
                                          isVideo: _isVideo(_post),
                                          heroTag: '',
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
                                child: _isVideo(_post)
                                    ? SizedBox(
                                        height: 300,
                                        child: VideoPlayerWidget(
                                          videoUrl: _post.primaryMediaUrl!,
                                        ),
                                      )
                                    : Image.network(
                                        _post.primaryMediaUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const SizedBox.shrink();
                                            },
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Like button
                              InkWell(
                                onTap: () {
                                  feedProvider.toggleLike(_post.id);
                                  setState(() {
                                    final wasLiked = _post.isLiked;
                                    _post = _post.copyWith(
                                      likes: wasLiked ? _post.likes - 1 : _post.likes + 1,
                                      isLiked: !wasLiked,
                                    );
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _post.isLiked ? Icons.favorite : Icons.favorite_border,
                                        size: 20,
                                        color: _post.isLiked ? Colors.red : colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${_post.likes}'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Comment count
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text('${_post.comments}'),
                              const SizedBox(width: 16),
                              // Repost button
                              InkWell(
                                onTap: () {
                                  final wasReposted = feedProvider.isReposted(_post.id);
                                  feedProvider.toggleRepost(_post.id);
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          wasReposted ? 'Removed repost' : 'Reposted to your profile',
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.repeat,
                                        size: 20,
                                        color: feedProvider.isReposted(_post.id)
                                            ? const Color(0xFF10B981)
                                            : colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${feedProvider.getRepostCount(_post.id)}'),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Report button (for non-authors)
                              if (!isAuthor)
                                InkWell(
                                  onTap: () => _handleReportPost(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.flag_outlined,
                                      size: 20,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Comments',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_comments.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_comments.length}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No comments yet. Be the first to verify!',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage:
                                          comment.author.avatar != null
                                          ? NetworkImage(comment.author.avatar!)
                                          : null,
                                      backgroundColor:
                                          colors.surfaceContainerHighest,
                                      child: comment.author.avatar == null
                                          ? Icon(
                                              Icons.person,
                                              size: 20,
                                              color: colors.onSurfaceVariant,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      comment.author.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      humanReadableTime(comment.timestamp),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment.text,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  // Add extra padding at bottom for the input field
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _submittingComment ? null : _submitComment,
                    icon: _submittingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReportPost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReportSheet(
        reportType: 'post',
        referenceId: _post.id,
        reportedUserId: _post.authorId,
        username: _post.author.username,
      ),
    );
  }

  bool _isVideo(Post post) {
    if (post.mediaList != null && post.mediaList!.isNotEmpty) {
      return post.mediaList!.first.mediaType == 'video';
    }
    // Fallback check by extension if legacy
    if (post.mediaUrl != null) {
      final url = post.mediaUrl!.toLowerCase();
      return url.endsWith('.mp4') ||
          url.endsWith('.mov') ||
          url.endsWith('.avi');
    }
    return false;
  }
}
