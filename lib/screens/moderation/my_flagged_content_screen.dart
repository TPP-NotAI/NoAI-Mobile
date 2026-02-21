import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/post.dart';
import '../../models/comment.dart';
import '../../models/story.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/post_repository.dart';
import '../../repositories/comment_repository.dart';
import '../../repositories/story_repository.dart';
import '../../config/app_colors.dart';
import '../../widgets/video_player_widget.dart';
import 'appeal_form_screen.dart';
import 'my_appeals_screen.dart';

class MyFlaggedContentScreen extends StatefulWidget {
  const MyFlaggedContentScreen({super.key});

  @override
  State<MyFlaggedContentScreen> createState() => _MyFlaggedContentScreenState();
}

class _MyFlaggedContentScreenState extends State<MyFlaggedContentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _postRepo = PostRepository();
  final _commentRepo = CommentRepository();
  final _storyRepo = StoryRepository();

  List<Post> _flaggedPosts = [];
  List<Comment> _flaggedComments = [];
  List<Story> _flaggedStories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      _postRepo.getUserFlaggedPosts(userId),
      _commentRepo.getUserFlaggedComments(userId),
      _storyRepo.getUserFlaggedStories(userId),
    ]);

    if (mounted) {
      setState(() {
        _flaggedPosts = results[0] as List<Post>;
        _flaggedComments = results[1] as List<Comment>;
        _flaggedStories = results[2] as List<Story>;
        _loading = false;
      });
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirm = await _confirmDelete(context, 'post');
    if (!confirm) return;
    await _postRepo.deletePost(post.id, currentUserId: post.authorId);
    setState(() => _flaggedPosts.removeWhere((p) => p.id == post.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirm = await _confirmDelete(context, 'comment');
    if (!confirm) return;
    await _commentRepo.deleteComment(
      comment.id,
      currentUserId: comment.authorId ?? '',
    );
    setState(() => _flaggedComments.removeWhere((c) => c.id == comment.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted.')),
      );
    }
  }

  Future<void> _deleteStory(Story story) async {
    final confirm = await _confirmDelete(context, 'story');
    if (!confirm) return;
    await _storyRepo.deleteStory(storyId: story.id, userId: story.userId);
    setState(() => _flaggedStories.removeWhere((s) => s.id == story.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story deleted.')),
      );
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String type) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Delete $type?'),
            content: Text(
              'This will permanently delete this $type. You cannot undo this.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _appealPost(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AppealFormScreen(post: post)),
    ).then((appealed) {
      if (appealed == true) {
        setState(() => _flaggedPosts.removeWhere((p) => p.id == post.id));
      }
    });
  }

  void _appealComment(Comment comment) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AppealFormScreen(comment: comment)),
    ).then((appealed) {
      if (appealed == true) {
        setState(() =>
            _flaggedComments.removeWhere((c) => c.id == comment.id));
      }
    });
  }

  void _appealStory(Story story) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AppealFormScreen(story: story)),
    ).then((appealed) {
      if (appealed == true) {
        setState(() =>
            _flaggedStories.removeWhere((s) => s.id == story.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(
          'My Flagged Content',
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My Appeals',
            icon: Icon(Icons.gavel_rounded, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyAppealsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.5),
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              text:
                  'Posts${_flaggedPosts.isNotEmpty ? ' (${_flaggedPosts.length})' : ''}',
            ),
            Tab(
              text:
                  'Comments${_flaggedComments.isNotEmpty ? ' (${_flaggedComments.length})' : ''}',
            ),
            Tab(
              text:
                  'Stories${_flaggedStories.isNotEmpty ? ' (${_flaggedStories.length})' : ''}',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.orange.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.smart_toy_outlined,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Content below was flagged by our AI system as '
                          'potentially AI-generated. You can appeal if you '
                          'believe this is a mistake, or delete the content.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _PostTab(
                        posts: _flaggedPosts,
                        onAppeal: _appealPost,
                        onDelete: _deletePost,
                        onRefresh: _load,
                      ),
                      _CommentTab(
                        comments: _flaggedComments,
                        onAppeal: _appealComment,
                        onDelete: _deleteComment,
                        onRefresh: _load,
                      ),
                      _StoryTab(
                        stories: _flaggedStories,
                        onAppeal: _appealStory,
                        onDelete: _deleteStory,
                        onRefresh: _load,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Posts tab
// ─────────────────────────────────────────────────────────────────────────────

class _PostTab extends StatelessWidget {
  final List<Post> posts;
  final void Function(Post) onAppeal;
  final void Function(Post) onDelete;
  final Future<void> Function() onRefresh;

  const _PostTab({
    required this.posts,
    required this.onAppeal,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        message: 'No AI-flagged posts',
        sub: 'None of your posts have been flagged by our AI system.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final post = posts[i];
          return _PostFlaggedCard(
            post: post,
            onAppeal: () => onAppeal(post),
            onDelete: () => onDelete(post),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments tab
// ─────────────────────────────────────────────────────────────────────────────

class _CommentTab extends StatelessWidget {
  final List<Comment> comments;
  final void Function(Comment) onAppeal;
  final void Function(Comment) onDelete;
  final Future<void> Function() onRefresh;

  const _CommentTab({
    required this.comments,
    required this.onAppeal,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        message: 'No AI-flagged comments',
        sub: 'None of your comments have been flagged by our AI system.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: comments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final comment = comments[i];
          return _CommentFlaggedCard(
            comment: comment,
            onAppeal: () => onAppeal(comment),
            onDelete: () => onDelete(comment),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stories tab
// ─────────────────────────────────────────────────────────────────────────────

class _StoryTab extends StatelessWidget {
  final List<Story> stories;
  final void Function(Story) onAppeal;
  final void Function(Story) onDelete;
  final Future<void> Function() onRefresh;

  const _StoryTab({
    required this.stories,
    required this.onAppeal,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        message: 'No AI-flagged stories',
        sub: 'None of your stories have been flagged by our AI system.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final story = stories[i];
          return _StoryFlaggedCard(
            story: story,
            onAppeal: () => onAppeal(story),
            onDelete: () => onDelete(story),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Story flagged card
// ─────────────────────────────────────────────────────────────────────────────

class _StoryFlaggedCard extends StatelessWidget {
  final Story story;
  final VoidCallback onAppeal;
  final VoidCallback onDelete;

  const _StoryFlaggedCard({
    required this.story,
    required this.onAppeal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final score = story.aiScore;
    final isFlagged = score != null && score >= 75;
    final scoreColor = isFlagged ? Colors.red : Colors.orange;

    final mediaItems = <_MediaItem>[
      _MediaItem(url: story.mediaUrl, type: story.mediaType),
    ];

    return _FlaggedCardShell(
      label: 'STORY',
      isFlagged: isFlagged,
      scoreColor: scoreColor,
      timestamp: story.createdAt.toIso8601String(),
      aiScore: score,
      authenticityNotes: story.aiMetadata?['rationale'] as String?,
      aiMetadata: story.aiMetadata,
      verificationMethod: null,
      mediaItems: mediaItems,
      text: story.caption ?? story.textOverlay ?? '',
      onAppeal: onAppeal,
      onDelete: onDelete,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post flagged card
// ─────────────────────────────────────────────────────────────────────────────

class _PostFlaggedCard extends StatelessWidget {
  final Post post;
  final VoidCallback onAppeal;
  final VoidCallback onDelete;

  const _PostFlaggedCard({
    required this.post,
    required this.onAppeal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final score = post.aiConfidenceScore ?? post.aiScore;
    final isFlagged = score != null && score >= 75;
    final scoreColor = isFlagged ? Colors.red : Colors.orange;

    // Build media list from mediaList or single mediaUrl
    final mediaItems = <_MediaItem>[];
    if (post.mediaList != null && post.mediaList!.isNotEmpty) {
      for (final m in post.mediaList!) {
        final url = m.storagePath.startsWith('http')
            ? m.storagePath
            : post.primaryMediaUrl ?? m.storagePath;
        mediaItems.add(_MediaItem(url: url, type: m.mediaType));
      }
    } else if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
      mediaItems.add(_MediaItem(url: post.mediaUrl!, type: 'image'));
    }

    return _FlaggedCardShell(
      label: 'POST',
      isFlagged: isFlagged,
      scoreColor: scoreColor,
      timestamp: post.timestamp,
      aiScore: score,
      authenticityNotes: post.authenticityNotes,
      aiMetadata: post.aiMetadata,
      verificationMethod: post.verificationMethod,
      mediaItems: mediaItems,
      text: post.content,
      onAppeal: onAppeal,
      onDelete: onDelete,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comment flagged card
// ─────────────────────────────────────────────────────────────────────────────

class _CommentFlaggedCard extends StatelessWidget {
  final Comment comment;
  final VoidCallback onAppeal;
  final VoidCallback onDelete;

  const _CommentFlaggedCard({
    required this.comment,
    required this.onAppeal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final score = comment.aiScore;
    final isFlagged = score != null && score >= 75;
    final scoreColor = isFlagged ? Colors.red : Colors.orange;

    final mediaItems = <_MediaItem>[];
    if (comment.mediaUrl != null && comment.mediaUrl!.isNotEmpty) {
      mediaItems.add(
        _MediaItem(
          url: comment.mediaUrl!,
          type: comment.mediaType ?? 'image',
        ),
      );
    }

    return _FlaggedCardShell(
      label: 'COMMENT',
      isFlagged: isFlagged,
      scoreColor: scoreColor,
      timestamp: comment.timestamp,
      aiScore: score,
      authenticityNotes: comment.authenticityNotes,
      aiMetadata: comment.aiMetadata,
      verificationMethod: null,
      mediaItems: mediaItems,
      text: comment.text,
      onAppeal: onAppeal,
      onDelete: onDelete,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared data class
// ─────────────────────────────────────────────────────────────────────────────

class _MediaItem {
  final String url;
  final String type; // 'image' | 'video'
  const _MediaItem({required this.url, required this.type});
}

// ─────────────────────────────────────────────────────────────────────────────
// Card shell — stateful for Read more / Read less
// ─────────────────────────────────────────────────────────────────────────────

class _FlaggedCardShell extends StatefulWidget {
  final String label;
  final bool isFlagged;
  final Color scoreColor;
  final String timestamp;
  final double? aiScore;
  final String? authenticityNotes;
  final Map<String, dynamic>? aiMetadata;
  final String? verificationMethod;
  final List<_MediaItem> mediaItems;
  final String text;
  final VoidCallback onAppeal;
  final VoidCallback onDelete;

  const _FlaggedCardShell({
    required this.label,
    required this.isFlagged,
    required this.scoreColor,
    required this.timestamp,
    required this.aiScore,
    required this.authenticityNotes,
    required this.aiMetadata,
    required this.verificationMethod,
    required this.mediaItems,
    required this.text,
    required this.onAppeal,
    required this.onDelete,
  });

  @override
  State<_FlaggedCardShell> createState() => _FlaggedCardShellState();
}

class _FlaggedCardShellState extends State<_FlaggedCardShell> {
  // Collapse text after this many characters
  static const int _threshold = 220;
  bool _expanded = false;

  bool get _isLong => widget.text.length > _threshold;
  String get _statusLabel =>
      widget.isFlagged ? 'AI FLAGGED' : 'UNDER AI REVIEW';
  Color get _borderColor =>
      widget.scoreColor.withValues(alpha: 0.4);
  Color get _headerBg =>
      widget.scoreColor.withValues(alpha: 0.07);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    color: widget.scoreColor, size: 15),
                const SizedBox(width: 6),
                Text(
                  '${widget.label}  ·  $_statusLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.scoreColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(
                    DateTime.tryParse(widget.timestamp) ?? DateTime.now(),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // ── Media ────────────────────────────────────────────────
          if (widget.mediaItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMedia(),
          ],

          // ── Text content ─────────────────────────────────────────
          if (widget.text.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                _isLong && !_expanded
                    ? '${widget.text.substring(0, _threshold)}…'
                    : widget.text,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            if (_isLong)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 4),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Read less' : 'Read more',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ] else if (widget.mediaItems.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                '[No content]',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 10),

          // ── AI score badge ───────────────────────────────────────
          if (widget.aiScore != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 13, color: widget.scoreColor),
                  const SizedBox(width: 4),
                  Text(
                    'AI-generated probability: '
                    '${widget.aiScore!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.scoreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ── Detection metadata box ───────────────────────────────
          if (_hasMetadata) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.scoreColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.scoreColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: widget.scoreColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.policy_outlined,
                              size: 13, color: widget.scoreColor),
                          const SizedBox(width: 5),
                          Text(
                            'Detection Details',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.scoreColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildMetadataRows(scheme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action buttons ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onAppeal,
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('Appeal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(AppLocalizations.of(context)!.delete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  bool get _hasMetadata {
    final notes = widget.authenticityNotes;
    final meta = widget.aiMetadata;
    return (notes != null && notes.isNotEmpty) ||
        (meta != null && meta.isNotEmpty);
  }

  List<Widget> _buildMetadataRows(ColorScheme scheme) {
    final rows = <Widget>[];
    final meta = widget.aiMetadata ?? {};

    // Helper to add a labeled row
    void add(IconData icon, String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      rows.add(_MetaRow(icon: icon, label: label, value: value,
          color: widget.scoreColor, scheme: scheme));
    }

    // Reason / rationale (highest priority — what the AI actually said)
    final rationale = meta['rationale']?.toString();
    final notes = widget.authenticityNotes;
    final reason = (rationale != null && rationale.isNotEmpty) ? rationale : notes;
    add(Icons.info_outline, 'Reason', reason);

    // Classification label (e.g. "AI-GENERATED", "HUMAN")
    final classification = meta['classification']?.toString();
    add(Icons.label_outline, 'Classification', classification);

    // Combined evidence summary (can be a String or List) — expandable
    final rawEvidence = meta['combined_evidence'];
    String? evidence;
    if (rawEvidence is String) {
      evidence = rawEvidence.isNotEmpty ? rawEvidence : null;
    } else if (rawEvidence is List && rawEvidence.isNotEmpty) {
      evidence = rawEvidence.map((e) => e.toString()).join('\n');
    }
    if (evidence != null && evidence.isNotEmpty) {
      rows.add(_ExpandableMetaRow(
        icon: Icons.analytics_outlined,
        label: 'Evidence',
        value: evidence,
        color: widget.scoreColor,
        scheme: scheme,
      ));
    }

    // Consensus strength (e.g. "strong", "weak", "moderate")
    final consensus = meta['consensus_strength']?.toString();
    add(Icons.group_outlined, 'Consensus', consensus);

    // Safety / content score
    final safety = meta['safety_score'];
    if (safety != null) {
      add(Icons.shield_outlined, 'Safety score',
          '${(safety as num).toStringAsFixed(1)}%');
    }

    // Detection type (text vs image)
    if (widget.verificationMethod != null) {
      add(Icons.search_outlined, 'Detected via', widget.verificationMethod);
    }

    // Metadata signals (e.g. "no EXIF data", "synthetic texture")
    final signals = meta['metadata_signals'];
    if (signals is List && signals.isNotEmpty) {
      add(Icons.sensors_outlined, 'Signals', signals.join(' · '));
    } else if (signals is String && signals.isNotEmpty) {
      add(Icons.sensors_outlined, 'Signals', signals);
    }

    // Model breakdown (individual model votes)
    final modelResults = meta['model_results'];
    if (modelResults is List && modelResults.isNotEmpty) {
      final parts = <String>[];
      for (final m in modelResults) {
        if (m is Map) {
          final name = m['model'] ?? m['name'] ?? 'Model';
          final conf = m['confidence'];
          final res = m['result'] ?? m['label'] ?? '';
          if (conf != null) {
            parts.add('$name: $res (${(conf as num).toStringAsFixed(0)}%)');
          } else {
            parts.add('$name: $res');
          }
        }
      }
      if (parts.isNotEmpty) {
        add(Icons.psychology_outlined, 'Model votes', parts.join('\n'));
      }
    }

    if (rows.isEmpty) {
      rows.add(Text(
        'No detailed information available.',
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurface.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      ));
    }

    // Insert dividers between rows
    final spaced = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      spaced.add(rows[i]);
      if (i < rows.length - 1) spaced.add(const SizedBox(height: 6));
    }
    return spaced;
  }

  Widget _buildMedia() {
    final items = widget.mediaItems;

    if (items.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _MediaTile(item: items.first, height: 220),
      );
    }

    // Multiple media — horizontal scrollable row
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(
          width: 180,
          child: _MediaTile(item: items[i], height: 180),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single media tile (image or video)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Single metadata row (icon + label + value)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme scheme;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable metadata row — for long fields like Evidence
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableMetaRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme scheme;

  const _ExpandableMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.scheme,
  });

  @override
  State<_ExpandableMetaRow> createState() => _ExpandableMetaRowState();
}

class _ExpandableMetaRowState extends State<_ExpandableMetaRow> {
  static const int _collapseAt = 120; // chars before "Read more"
  bool _expanded = false;

  bool get _isLong => widget.value.length > _collapseAt;
  String get _displayText => _isLong && !_expanded
      ? '${widget.value.substring(0, _collapseAt)}…'
      : widget.value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(widget.icon, size: 14, color: widget.color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.scheme.onSurface.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${widget.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: _displayText),
                  ],
                ),
              ),
              if (_isLong)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Read less' : 'Read more',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single media tile (image or video)
// ─────────────────────────────────────────────────────────────────────────────

class _MediaTile extends StatelessWidget {
  final _MediaItem item;
  final double height;

  const _MediaTile({required this.item, required this.height});

  bool get _isVideo =>
      item.type == 'video' ||
      item.url.contains('.mp4') ||
      item.url.contains('.mov') ||
      item.url.contains('.webm');

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          child: VideoPlayerWidget(videoUrl: item.url),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: item.url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: height,
          color: Colors.grey.withValues(alpha: 0.15),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: height,
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.green.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}


