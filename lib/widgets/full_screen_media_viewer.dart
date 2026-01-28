import 'package:flutter/material.dart';
import '../models/post.dart';
import '../config/supabase_config.dart';
import 'video_player_widget.dart';

class FullScreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;
  final String heroTag;
  final List<PostMedia>? mediaList;
  final int initialIndex;

  const FullScreenMediaViewer({
    super.key,
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/media/${media.storagePath}';
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
