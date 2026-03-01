import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'shimmer_loading.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? videoUrl;
  final File? videoFile;
  final bool autoPlay;
  final bool looping;
  final bool showControls;

  const VideoPlayerWidget({
    super.key,
    this.videoUrl,
    this.videoFile,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = false,
  }) : assert(
         videoUrl != null || videoFile != null,
         'Either videoUrl or videoFile must be provided',
       );

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showIcon = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.videoUrl != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(widget.videoFile!);
      }

      await _videoPlayerController.initialize();

      if (widget.showControls) {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: widget.autoPlay,
          looping: widget.looping,
          aspectRatio: _videoPlayerController.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          showOptions: false,
          placeholder: const ShimmerLoading(
            isLoading: true,
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
          ),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );
      } else {
        _videoPlayerController.setLooping(widget.looping);
        if (widget.autoPlay) await _videoPlayerController.play();
      }

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
      }
      _showIcon = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showIcon = false);
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(
          child: Icon(Icons.videocam_off_outlined, size: 40, color: Colors.grey),
        ),
      );
    }

    if (!_isInitialized) {
      return const ShimmerLoading(
        isLoading: true,
        child: ShimmerBox(width: double.infinity, height: 200, borderRadius: 0),
      );
    }

    // Full controls mode (full screen viewer)
    if (widget.showControls && _chewieController != null) {
      return AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      );
    }

    // Play/pause icon only mode (post card & post detail)
    return AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoPlayerController),
            AnimatedOpacity(
              opacity: _showIcon || !_videoPlayerController.value.isPlaying
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _videoPlayerController.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
