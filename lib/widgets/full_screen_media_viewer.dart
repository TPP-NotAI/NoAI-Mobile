import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/supabase_config.dart';
import '../models/post.dart';
import '../providers/feed_provider.dart';
import '../utils/time_utils.dart';
import 'comments_sheet.dart';
import 'video_player_widget.dart';

class FullScreenMediaViewer extends StatefulWidget {
  final Post post;
  final String mediaUrl;
  final bool isVideo;
  final String heroTag;
  final List<PostMedia>? mediaList;
  final int initialIndex;

  const FullScreenMediaViewer({
    super.key,
    required this.post,
    required this.mediaUrl,
    required this.isVideo,
    required this.heroTag,
    this.mediaList,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _captionExpanded = false;
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likes;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getMediaUrl(PostMedia media) {
    if (media.storagePath.startsWith('http')) {
      return media.storagePath;
    }
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/${media.storagePath}';
  }

  @override
  Widget build(BuildContext context) {
    // If we have a media list, show swipeable gallery
    if (widget.mediaList != null && widget.mediaList!.isNotEmpty) {
      return _buildGalleryView();
    }

    // Single media view (backward compatible)
    return _buildSingleMediaView();
  }

  Widget _buildSingleMediaView() {
    final mediaWidget = widget.isVideo
        ? VideoPlayerWidget(videoUrl: widget.mediaUrl)
        : InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              widget.mediaUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, color: Colors.white),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
                child: widget.heroTag.isNotEmpty
                    ? Hero(tag: widget.heroTag, child: mediaWidget)
                    : mediaWidget,
              ),
          _buildOverlay(context),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildGalleryView() {
    final mediaCount = widget.mediaList!.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable media pages
          PageView.builder(
            controller: _pageController,
            itemCount: mediaCount,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final media = widget.mediaList![index];
              final url = _getMediaUrl(media);
              final isVideo = media.mediaType == 'video';

              if (isVideo) {
                return Center(
                  child: VideoPlayerWidget(videoUrl: url),
                );
              }

              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error, color: Colors.white, size: 48),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
            );
          },
        ),

        _buildOverlay(context),

          // Close button
          _buildCloseButton(),

          // Page indicator (if more than 1 media)
          if (mediaCount > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(mediaCount, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  );
                }),
              ),
            ),

          // Counter badge
          if (mediaCount > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / $mediaCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
        ),
      );
    }

  Widget _buildOverlay(BuildContext context) {
    final caption = widget.post.content.trim();
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return Positioned.fill(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnorePointer(
            ignoring: true,
            child: _buildAuthorBar(context),
          ),
          const Spacer(),
          if (caption.isNotEmpty) _buildCaption(context, caption),
          _buildStatsRow(context),
          SizedBox(height: bottomPadding + 12),
        ],
      ),
    );
  }

  Widget _buildAuthorBar(BuildContext context) {
    final author = widget.post.author;
    final name =
        author.displayName.isNotEmpty ? author.displayName : author.username;
    final timestampLabel = humanReadableTime(widget.post.timestamp);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildAvatar(author),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (author.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.verified,
                              color: Color(0xFF38BDF8),
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${author.username} · $timestampLabel',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(PostAuthor author) {
    if (author.avatar.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white24,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white24,
      backgroundImage: CachedNetworkImageProvider(author.avatar),
    );
  }

  Widget _buildCaption(BuildContext context, String caption) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _captionExpanded = !_captionExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            caption,
            maxLines: _captionExpanded ? null : 3,
            overflow: _captionExpanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  void _handleLike() {
    context.read<FeedProvider>().toggleLike(widget.post.id);
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
  }

  void _handleComment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(post: widget.post),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatButton(
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              value: _formatCount(_likeCount),
              label: 'Likes',
              isActive: _isLiked,
              onTap: _handleLike,
            ),
            _buildStatButton(
              icon: Icons.chat_bubble_outline,
              value: _formatCount(widget.post.comments),
              label: 'Comments',
              onTap: _handleComment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatButton({
    required IconData icon,
    required String value,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isActive ? Colors.red : Colors.white70),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isActive ? Colors.red : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildCloseButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
