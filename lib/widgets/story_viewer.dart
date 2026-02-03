import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/supabase_config.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import 'video_player_widget.dart';

class StoryViewer extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markViewed(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _markViewed(int index) {
    if (index < 0 || index >= widget.stories.length) return;
    final story = widget.stories[index];
    if (!story.isViewed) {
      setState(() {
        widget.stories[index] =
            story.copyWith(isViewed: true, viewCount: story.viewCount + 1);
      });
    }
    context.read<StoryProvider>().markViewed(story);
  }

  Future<void> _showViewersSheet() async {
    if (!mounted || widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Viewers',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<User>>(
                  future:
                      context.read<StoryProvider>().fetchViewers(story.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }
                    final viewers = snapshot.data ?? [];
                    if (viewers.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No views yet.',
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.8),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Colors.white12,
                        height: 1,
                      ),
                      itemBuilder: (_, index) {
                        final viewer = viewers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.surfaceVariant,
                            backgroundImage: viewer.avatar != null
                                ? NetworkImage(viewer.avatar!)
                                : null,
                            child: viewer.avatar == null
                                ? Icon(Icons.person, color: colors.onSurfaceVariant)
                                : null,
                          ),
                          title: Text(
                            viewer.displayName.isNotEmpty
                                ? viewer.displayName
                                : viewer.username,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Viewed your story',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteStory() async {
    if (!mounted || widget.stories.isEmpty) return;
    final story = widget.stories[_currentIndex];

    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete story?'),
            content: const Text(
              'This will remove the status for everyone. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    final deleted =
        await context.read<StoryProvider>().deleteStory(story.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Story deleted' : 'Failed to delete story',
        ),
      ),
    );

    if (deleted) {
      setState(() {
        widget.stories.removeAt(_currentIndex);
        if (_currentIndex >= widget.stories.length) {
          _currentIndex = widget.stories.isEmpty ? 0 : widget.stories.length - 1;
        }
      });
      if (widget.stories.isEmpty) {
        Navigator.of(context).maybePop();
      }
    }
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _markViewed(index);
            },
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: story.mediaType == 'video'
                        ? VideoPlayerWidget(videoUrl: _resolveUrl(story.mediaUrl))
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: Image.network(
                              _resolveUrl(story.mediaUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child:
                                    Icon(Icons.broken_image, color: Colors.white),
                              ),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  _buildCaptionOverlay(story, colors),
                ],
              );
            },
          ),
          _buildTopBar(context),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final colors = Theme.of(context).colorScheme;
    final authUser = context.watch<AuthProvider>().currentUser;
    final isOwner = authUser?.id == story.userId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.surfaceVariant,
              backgroundImage: story.author.avatar != null
                  ? NetworkImage(story.author.avatar!)
                  : null,
              child: story.author.avatar == null
                  ? Icon(Icons.person, color: colors.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(width: 8),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Views: ${story.viewCount}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.white),
                tooltip: 'Viewers',
                onPressed: _showViewersSheet,
              ),
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'Delete story',
                onPressed: _confirmDeleteStory,
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (widget.stories.length <= 1) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
        child: Row(
          children: List.generate(widget.stories.length, (i) {
            final isActive = i == _currentIndex;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: i == widget.stories.length - 1 ? 0 : 6),
                height: 3.5,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCaptionOverlay(Story story, ColorScheme colors) {
    if ((story.caption == null || story.caption!.isEmpty) &&
        (story.textOverlay == null || story.textOverlay!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (story.caption != null && story.caption!.isNotEmpty)
              Text(
                story.caption!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (story.textOverlay != null && story.textOverlay!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  story.textOverlay!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
