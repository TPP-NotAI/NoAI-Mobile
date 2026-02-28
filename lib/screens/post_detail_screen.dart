import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/report_sheet.dart';
import '../utils/time_utils.dart';
import 'create/edit_post_screen.dart';
import 'hashtag_feed_screen.dart';
import '../widgets/mention_rich_text.dart';
import '../widgets/mention_autocomplete_field.dart';
import '../utils/verification_utils.dart';
import '../widgets/verification_required_widget.dart';
import '../services/viral_content_service.dart';
import '../widgets/comment_card.dart';
import '../widgets/boost_post_modal.dart';
import '../widgets/post_card.dart' show PostMediaGridView;
import '../widgets/tip_modal.dart';
import '../screens/boost/boost_analytics_page.dart';
import '../screens/ads/ad_insights_page.dart';
import '../repositories/boost_repository.dart';
import '../repositories/wallet_repository.dart';
import '../services/rooken_service.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
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
  bool _isTextExpanded = false;
  bool _isBoosted = false;
  Comment? _replyingTo;

  static const int _maxLinesCollapsed = 4;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _editController = TextEditingController(text: _post.content);
    _loadComments();
    _checkViralReward();
    _loadBoostStatus();
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
    int visibleCount = 0;
    for (final comment in comments) {
      visibleCount++;
      visibleCount += comment.replies?.length ?? 0;
    }
    if (mounted) {
      setState(() {
        _comments = comments;
        _loadingComments = false;
        _post = _post.copyWith(comments: visibleCount);
      });
    }
  }

  Future<void> _checkViralReward() async {
    try {
      final viralService = ViralContentService();
      await viralService.checkAndRewardViralPost(_post.id, _post.authorId);
    } catch (e) {
      debugPrint('PostDetailScreen: Error checking viral reward - $e');
    }
  }

  Future<void> _loadBoostStatus() async {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    if (currentUserId == null || currentUserId != _post.authorId) return;
    try {
      final boostedIds = await BoostRepository().getBoostedPostIds(currentUserId);
      if (!mounted) return;
      setState(() {
        _isBoosted = boostedIds.contains(_post.id);
      });
    } catch (e) {
      debugPrint('PostDetailScreen: Error loading boost status - $e');
    }
  }

  bool get _isAdvertPost {
    final notes = (_post.authenticityNotes ?? '').toLowerCase();
    if (notes.contains('advertisement:')) return true;
    final ad = _post.aiMetadata?['advertisement'];
    if (ad is Map) {
      return ad['requires_payment'] == true ||
          (ad['confidence'] is num && (ad['confidence'] as num) >= 40);
    }
    return false;
  }

  void _openHashtagFeed(String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HashtagFeedScreen(hashtag: hashtag)),
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final isActivated = await VerificationUtils.checkActivation(context);
    if (!mounted || !isActivated) return;

    setState(() => _submittingComment = true);

    final feedProvider = context.read<FeedProvider>();
    final replyTarget = _replyingTo;

    if (replyTarget != null) {
      // Build optimistic reply using current user's info
      final currentUser = context.read<AuthProvider>().currentUser;
      final tempId = 'temp_reply_${DateTime.now().millisecondsSinceEpoch}';
      final tempReply = Comment(
        id: tempId,
        authorId: currentUser?.id,
        author: CommentAuthor(
          displayName: currentUser?.displayName ?? '',
          username: currentUser?.username ?? '',
          avatar: currentUser?.avatar,
        ),
        text: text,
        timestamp: DateTime.now().toIso8601String(),
      );

      // Optimistic: inject into local _comments immediately so it shows
      _commentController.clear();
      setState(() {
        _replyingTo = null;
        _submittingComment = false;
        _comments = _addReplyToComments(_comments, replyTarget.id, tempReply);
      });

      try {
        await feedProvider.addReply(_post.id, replyTarget.id, text, tempId);
      } catch (e) {
        if (mounted) {
          // Roll back the optimistic reply on failure
          setState(() {
            _comments = _removeReplyFromComments(_comments, tempId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to post reply'.tr(context))),
          );
        }
      }
    } else {
      // Submit as a top-level comment
      final newComment = await feedProvider.addComment(_post.id, text);
      if (mounted) {
        setState(() => _submittingComment = false);
        if (newComment != null) {
          _commentController.clear();
          setState(() {
            _comments.add(newComment);
            _post = _post.copyWith(comments: _post.comments + 1);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Comment posted!'.tr(context))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to post comment'.tr(context))),
          );
        }
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
        title: Text('Unpublish Post?'.tr(context)),
        content: Text('This will remove the post from the public feed. You can republish it later (not implemented yet).'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unpublish'.tr(context)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final feedProvider = context.read<FeedProvider>();
      final success = await feedProvider.unpublishPost(_post.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context); // Go back to feed/profile
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Post unpublished'.tr(context))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unpublish post. You can only unpublish your own posts.'.tr(context),
              ),
            ),
          );
        }
      }
    }
  }

  void _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post?'.tr(context)),
        content: Text('Are you sure you want to delete this post? This action cannot be undone.'.tr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final feedProvider = context.read<FeedProvider>();
      final success = await feedProvider.deletePost(_post.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context); // Go back
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Post deleted'.tr(context))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete post. You can only delete your own posts.'.tr(context),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleBoost() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoostPostModal(post: _post),
    );
    await _loadBoostStatus();
  }

  void _handleBoostAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BoostAnalyticsPage(post: _post)),
    );
  }

  void _handleAdInsights() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdInsightsPage(post: _post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final feedProvider = context.watch<FeedProvider>();
    final isAuthor = authProvider.currentUser?.id == _post.authorId;
    final colors = Theme.of(context).colorScheme;
    final totalCommentCount = _countCommentsWithReplies(_comments);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _post);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text('Post Details'.tr(context)),
        actions: [
          if (isAuthor)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _handleEdit();
                    break;
                  case 'boost':
                    _handleBoost();
                    break;
                  case 'boost_analytics':
                    _handleBoostAnalytics();
                    break;
                  case 'ad_insights':
                    _handleAdInsights();
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
                PopupMenuItem(
                  value: 'boost',
                  child: Row(
                    children: [
                      Icon(Icons.rocket_launch, size: 20),
                      SizedBox(width: 12),
                      Text('Boost Post'.tr(context)),
                    ],
                  ),
                ),
                if (_isBoosted)
                  PopupMenuItem(
                    value: 'boost_analytics',
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, size: 20),
                        SizedBox(width: 12),
                        Text('View Boost Analytics'.tr(context)),
                      ],
                    ),
                  ),
                if (_isAdvertPost)
                  PopupMenuItem(
                    value: 'ad_insights',
                    child: Row(
                      children: [
                        Icon(Icons.insights_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Ad Insights'.tr(context)),
                      ],
                    ),
                  ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Post'.tr(context)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'unpublish',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, size: 20),
                      SizedBox(width: 12),
                      Text('Unpublish'.tr(context)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(width: 12),
                      Text('Delete'.tr(context),
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
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                        if (_post.author.isVerified) ...[
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.verified,
                                            size: 14,
                                            color: colors.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text('@${_post.author.username}'.tr(context),
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
                          SizedBox(height: 16),
                          // Moderation Alert for Author
                          if (isAuthor &&
                              (_post.status == 'deleted' ||
                                  _post.status == 'under_review' ||
                                  _post.status == 'flagged'))
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    (_post.status == 'deleted'
                                            ? colors.error
                                            : colors.tertiary)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      (_post.status == 'deleted'
                                              ? colors.error
                                              : colors.tertiary)
                                          .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _post.status == 'deleted'
                                        ? Icons.block
                                        : Icons.warning_amber_rounded,
                                    color: _post.status == 'deleted'
                                        ? colors.error
                                        : colors.tertiary,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _post.status == 'deleted'
                                              ? 'Post Rejected/Deleted'
                                              : 'Post Under Review',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _post.status == 'deleted'
                                                ? colors.error
                                                : colors.tertiary,
                                          ),
                                        ),
                                        if (_post.authenticityNotes != null)
                                          Text(
                                            _post.authenticityNotes!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _post.status == 'deleted'
                                                  ? colors.onErrorContainer
                                                  : colors.onTertiaryContainer,
                                            ),
                                          ),
                                        if (_post.aiScoreStatus != null)
                                          Text('Status: ${_post.aiScoreStatus}'.tr(context),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: _post.status == 'deleted'
                                                  ? colors.onErrorContainer
                                                  : colors.onTertiaryContainer,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_post.isSensitive)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.errorContainer.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: colors.error,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Sensitive Content'.tr(context),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: colors.error,
                                          ),
                                        ),
                                        if (_post.sensitiveReason != null)
                                          Text(
                                            _post.sensitiveReason!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onErrorContainer,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_post.title != null &&
                              _post.title!.isNotEmpty) ...[
                            MentionRichText(
                              text: _post.title!,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              onMentionTap: (username) =>
                                  navigateToMentionedUser(context, username),
                              onHashtagTap: _openHashtagFeed,
                            ),
                            SizedBox(height: 8),
                          ],
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final textStyle = Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(height: 1.6);
                              final textSpan = TextSpan(
                                text: _post.content,
                                style: textStyle,
                              );
                              final textPainter = TextPainter(
                                text: textSpan,
                                maxLines: _maxLinesCollapsed,
                                textDirection: TextDirection.ltr,
                              )..layout(maxWidth: constraints.maxWidth);
                              final isOverflowing =
                                  textPainter.didExceedMaxLines;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MentionRichText(
                                    text: _post.content,
                                    style: textStyle,
                                    maxLines: _isTextExpanded
                                        ? null
                                        : _maxLinesCollapsed,
                                    overflow: TextOverflow.clip,
                                    onMentionTap: (username) =>
                                        navigateToMentionedUser(
                                          context,
                                          username,
                                        ),
                                    onHashtagTap: _openHashtagFeed,
                                  ),
                                  if (isOverflowing)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isTextExpanded = !_isTextExpanded;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _isTextExpanded
                                              ? 'Show less'
                                              : '... more',
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: 16),
                          if (_post.location != null &&
                              _post.location!.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _post.location!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                          ],
                          if (_post.tags != null && _post.tags!.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _post.tags!.map((tag) {
                                return GestureDetector(
                                  onTap: () => _openHashtagFeed(tag.name),
                                  child: Text('#${tag.name}'.tr(context),
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 16),
                          ],
                          if (_post.hasMedia) ...[
                            PostMediaGridView(
                              post: _post,
                              padding: EdgeInsets.zero,
                            ),
                            SizedBox(height: 16),
                          ],
                          SizedBox(height: 16),
                          Row(
                            children: [
                              // Like button
                              InkWell(
                                onTap: () {
                                  feedProvider.toggleLike(_post.id);
                                  setState(() {
                                    final wasLiked = _post.isLiked;
                                    _post = _post.copyWith(
                                      likes: wasLiked
                                          ? _post.likes - 1
                                          : _post.likes + 1,
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
                                        _post.isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 20,
                                        color: _post.isLiked
                                            ? Colors.red
                                            : colors.onSurfaceVariant,
                                      ),
                                      SizedBox(width: 4),
                                      Text('${_post.likes}'.tr(context)),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              // Comment count
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: colors.onSurfaceVariant,
                              ),
                              SizedBox(width: 4),
                              Text('${_post.comments}'.tr(context)),
                              SizedBox(width: 16),
                              // Repost button
                              InkWell(
                                onTap: () {
                                  final wasReposted = feedProvider.isReposted(
                                    _post.id,
                                  );
                                  feedProvider.toggleRepost(_post.id);
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          wasReposted
                                              ? 'Removed repost'
                                              : 'Reposted to your profile',
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                      SizedBox(width: 4),
                                      Text('${feedProvider.getRepostCount(_post.id)}'.tr(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              // Tip button (for non-authors)
                              if (!isAuthor)
                                InkWell(
                                  onTap: () => _handleTip(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.toll,
                                          size: 20,
                                          color: colors.onSurfaceVariant,
                                        ),
                                        if (_post.tips > 0) ...[
                                          SizedBox(width: 4),
                                          Text('${_post.tips.toInt()} ROO'),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              Spacer(),
                              // Share button
                              InkWell(
                                onTap: () => _handleShare(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.share_outlined,
                                    size: 20,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
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
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Comments'.tr(context),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
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
                          child: Text('$totalCommentCount'.tr(context),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_loadingComments)
                    Center(child: CircularProgressIndicator())
                  else if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text('No comments yet. Be the first to verify!'.tr(context),
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
                        return CommentCard(
                          comment: comment,
                          postId: _post.id,
                          onReplyTap: (targetComment) {
                            setState(() => _replyingTo = targetComment);
                            _commentController.clear();
                          },
                        );
                      },
                    ),
                  // Add extra padding at bottom for the input field
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Comment Input
          if (authProvider.currentUser?.isActivated == true)
            Container(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        color: colors.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Replying to @${_replyingTo!.author.username}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyingTo = null),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: MentionAutocompleteField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: _replyingTo != null
                                    ? 'Reply to @${_replyingTo!.author.username}...'
                                    : 'Add a comment...',
                                filled: true,
                                fillColor: colors.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
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
                          SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _submittingComment ? null : _submitComment,
                            icon: _submittingComment
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: VerificationRequiredWidget(
                  message: 'Verify your identity to comment on this post.',
                  onVerifyTap: () {
                    if (context.mounted) {
                      Navigator.pushNamed(context, '/verify');
                    }
                  },
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  void _handleTip(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    if (user.isVerificationPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your verification is pending. You can tip once approved.'.tr(context)),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete identity verification to send tips.'.tr(context)),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Verify',
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) Navigator.pushNamed(context, '/verify');
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TipModal(post: _post),
    );
  }

  void _handleShare(BuildContext context) async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;

      final shareText = _post.title != null && _post.title!.isNotEmpty
          ? '${_post.title}\n\n${_post.content}\n\nShared from ROOVERSE'
          : '${_post.content}\n\nShared from ROOVERSE';

      await Share.share(
        shareText,
        subject: _post.title ?? 'Check out this post on ROOVERSE',
      );

      if (currentUserId != null && currentUserId.isNotEmpty) {
        try {
          final walletRepo = WalletRepository();
          await walletRepo.earnRoo(
            userId: currentUserId,
            activityType: RookenActivityType.postShare,
            referencePostId: _post.id,
          );
        } catch (e) {
          debugPrint('Error awarding share ROOK: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Post shared! You earned 5 ROOK.'.tr(context)),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      debugPrint('Error sharing post: $e');
    }
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

  // Recursively add a reply under the target comment in the local list
  List<Comment> _addReplyToComments(
    List<Comment> comments,
    String parentId,
    Comment reply,
  ) {
    return comments.map((c) {
      if (c.id == parentId) {
        return c.copyWith(replies: [...?c.replies, reply]);
      }
      if (c.replies != null && c.replies!.isNotEmpty) {
        return c.copyWith(
          replies: _addReplyToComments(c.replies!, parentId, reply),
        );
      }
      return c;
    }).toList();
  }

  // Recursively remove a reply by id from the local list (used for rollback)
  List<Comment> _removeReplyFromComments(List<Comment> comments, String replyId) {
    return comments.map((c) {
      if (c.replies != null && c.replies!.isNotEmpty) {
        return c.copyWith(
          replies: c.replies!
              .where((r) => r.id != replyId)
              .map((r) => _removeReplyFromComments([r], replyId).first)
              .toList(),
        );
      }
      return c;
    }).toList();
  }

  int _countCommentsWithReplies(List<Comment> comments) {
    int total = 0;
    for (final comment in comments) {
      total++;
      final replies = comment.replies;
      if (replies != null && replies.isNotEmpty) {
        total += _countCommentsWithReplies(replies);
      }
    }
    return total;
  }
}
