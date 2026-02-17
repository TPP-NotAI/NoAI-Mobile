import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/supabase_config.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import 'video_player_widget.dart';
import '../services/chat_service.dart';

class StoryViewer extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewer({super.key, required this.stories, this.initialIndex = 0});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late AnimationController _animationController;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ChatService _chatService = ChatService();
  int _currentIndex = 0;
  bool _isPaused = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // story duration
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _markViewed(_currentIndex); // Mark as viewed only when story completes
        _nextStory();
      }
    });

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _animationController.stop();
      } else {
        if (!_isPaused) _animationController.forward();
      }
    });

    _startStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _startStory() {
    _animationController.reset();
    _animationController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _markViewed(int index) {
    if (index < 0 || index >= widget.stories.length) return;
    final story = widget.stories[index];
    if (!story.isViewed) {
      setState(() {
        widget.stories[index] = story.copyWith(
          isViewed: true,
          viewCount: story.viewCount + 1,
        );
      });
    }
    context.read<StoryProvider>().markViewed(story);
  }

  Future<void> _showViewersSheet() async {
    if (!mounted || widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];
    _animationController.stop();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Viewers',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${story.viewCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: context.read<StoryProvider>().fetchViewers(
                      story.id,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final viewers = snapshot.data ?? [];
                      if (viewers.isEmpty) {
                        return const Center(
                          child: Text(
                            'No views yet',
                            style: TextStyle(color: Colors.white60),
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: controller,
                        itemCount: viewers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final viewerInfo = viewers[index];
                          final viewer = viewerInfo['user'] as User;
                          final viewedAt = viewerInfo['viewedAt'] as DateTime;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage: viewer.avatar != null
                                    ? NetworkImage(viewer.avatar!)
                                    : null,
                                child: viewer.avatar == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                viewer.displayName.isNotEmpty
                                    ? viewer.displayName
                                    : viewer.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Viewed ${_getRelativeTime(viewedAt)}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _animationController.forward();
  }

  Future<void> _confirmDeleteStory() async {
    if (!mounted || widget.stories.isEmpty) return;
    _animationController.stop();
    final story = widget.stories[_currentIndex];

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Delete story?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this story?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      _animationController.forward();
      return;
    }

    final deleted = await context.read<StoryProvider>().deleteStory(story.id);
    if (!mounted) return;

    if (deleted) {
      setState(() {
        widget.stories.removeAt(_currentIndex);
        if (widget.stories.isEmpty) {
          Navigator.of(context).maybePop();
        } else {
          if (_currentIndex >= widget.stories.length) {
            _currentIndex = widget.stories.length - 1;
          }
          _startStory();
        }
      });
    } else {
      _animationController.forward();
    }
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$url';
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Future<void> _sendReply({String? text}) async {
    final content = text ?? _replyController.text.trim();
    if (content.isEmpty) return;

    final story = widget.stories[_currentIndex];
    setState(() => _isSending = true);

    try {
      final conversation = await _chatService.getOrCreateConversation(
        story.userId,
      );
      await _chatService.sendMessage(
        conversation.id,
        content,
        replyToId:
            null, // Could optionally reference story here if DB supports it
      );

      if (mounted) {
        _replyController.clear();
        _replyFocusNode.unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final story =
        widget.stories[_currentIndex.clamp(0, widget.stories.length - 1)];
    final authUser = context.watch<AuthProvider>().currentUser;
    final isOwner = authUser?.id == story.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) {
          setState(() => _isPaused = true);
          _animationController.stop();
        },
        onLongPressEnd: (_) {
          setState(() => _isPaused = false);
          _animationController.forward();
        },
        child: Stack(
          children: [
            // Content
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _startStory();
              },
              itemBuilder: (context, index) {
                final s = widget.stories[index];
                return _buildStoryContent(s);
              },
            ),

            // Gestures mapping (Left/Right)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _previousStory,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _nextStory,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

            // Top Bar & Progress
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isPaused ? 0.0 : 1.0,
                child: Column(
                  children: [
                    _buildProgressBar(),
                    _buildTopBar(context, isOwner),
                  ],
                ),
              ),
            ),

            // Bottom Bar (Reply)
            if (!isOwner)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isPaused ? 0.0 : 1.0,
                  child: _buildReplyBar(),
                ),
              ),

            // Caption
            if (story.caption != null && story.caption!.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isPaused ? 0.0 : 1.0,
                  child: _buildCaption(story.caption!),
                ),
              ),

            if (isOwner)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isPaused ? 0.0 : 1.0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white,
                          size: 28,
                        ),
                        TextButton(
                          onPressed: _showViewersSheet,
                          child: Text(
                            '${story.viewCount} Views',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story story) {
    // Parse background color
    Color bgColor = Colors.black;
    if (story.backgroundColor != null && story.backgroundColor!.isNotEmpty) {
      try {
        final colorStr = story.backgroundColor!.replaceFirst('#', '');
        bgColor = Color(int.parse('FF$colorStr', radix: 16));
      } catch (_) {}
    }

    return Container(
      color: bgColor,
      child: Center(
        child: story.mediaType == 'text'
            // Text-only story - show text overlay centered
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  story.textOverlay ?? story.caption ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : story.mediaType == 'video'
            ? VideoPlayerWidget(videoUrl: _resolveUrl(story.mediaUrl))
            : story.mediaUrl.isNotEmpty
            ? Image.network(
                _resolveUrl(story.mediaUrl),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white24),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildProgressBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: List.generate(widget.stories.length, (i) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Stack(
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (i <= _currentIndex)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          double val = 0;
                          if (i < _currentIndex) {
                            val = 1.0;
                          } else if (i == _currentIndex) {
                            val = _animationController.value;
                          }

                          return FractionallySizedBox(
                            widthFactor: val,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isOwner) {
    final story = widget.stories[_currentIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: story.author.avatar != null
                ? NetworkImage(story.author.avatar!)
                : null,
            child: story.author.avatar == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.author.displayName.isNotEmpty
                      ? story.author.displayName
                      : story.author.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getRelativeTime(story.createdAt),
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          if (story.aiScore != null || story.status != null)
            _AiScoreBadge(score: story.aiScore, status: story.status),
          const SizedBox(width: 8),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white70),
              onPressed: _confirmDeleteStory,
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    final story = widget.stories[_currentIndex];
    final bool isLiked = story.isLiked ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (val) => _sendReply(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Reply...',
                hintStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => context.read<StoryProvider>().toggleLike(story),
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _sendReply,
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption(String caption) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        caption,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
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
      label = 'AI DETECTED';
    } else if (isReview) {
      badgeColor = const Color(0xFFF59E0B); // Amber
      bgColor = const Color(0xFF451A03);
      label = 'REVIEW REQ';
    } else {
      badgeColor = const Color(0xFF10B981); // Green
      bgColor = const Color(0xFF052E1C);
      label = 'HUMAN CERT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
