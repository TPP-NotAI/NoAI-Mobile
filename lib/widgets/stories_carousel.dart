import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rooverse/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:image/image.dart' as img;

import '../config/supabase_config.dart';
import '../config/app_spacing.dart';
import '../utils/responsive_extensions.dart';
import '../models/story.dart';
import '../models/story_media_input.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import '../utils/file_upload_utils.dart';
import '../utils/verification_utils.dart';
import '../services/supabase_service.dart';
import 'story_card.dart';
import 'story_viewer.dart';

class StoriesCarousel extends StatefulWidget {
  const StoriesCarousel({super.key});

  @override
  State<StoriesCarousel> createState() => _StoriesCarouselState();
}

class _StoriesCarouselState extends State<StoriesCarousel> {
  final ImagePicker _imagePicker = ImagePicker();

  // Media state
  final List<File> _selectedMediaFiles = [];
  final List<String> _selectedMediaTypes = []; // 'image' or 'video'

  // Video editing flags
  final Map<int, bool> _videoMuteFlags = {};
  final Map<int, int> _videoRotationFlags = {};

  @override
  Widget build(BuildContext context) {
    final storyProvider = context.watch<StoryProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final colors = Theme.of(context).colorScheme;

    final stories = storyProvider.latestStoriesPerUser;
    final myStories = storyProvider.currentUserStories;
    final hasOtherStories =
        stories.any((s) => s.userId != user?.id) && stories.isNotEmpty;

    // Loading skeleton
    if (storyProvider.isLoading && stories.isEmpty && myStories.isEmpty) {
      return Container(
        height: 104.responsive(context, min: 94, max: 114),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppSpacing.responsiveRadius(
            context,
            AppSpacing.radiusExtraLarge,
          ),
          border: Border.all(color: colors.outlineVariant),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.largePlus.responsive(context),
          vertical: AppSpacing.standard.responsive(context),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(
              5,
              (index) => Container(
                width: 64.responsive(context, min: 56, max: 72),
                height: 64.responsive(context, min: 56, max: 72),
                margin: EdgeInsets.only(
                  right: index == 4
                      ? 0
                      : AppSpacing.standard.responsive(context),
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cards = _buildStoryCards(
      context: context,
      userStories: myStories,
      otherStories: stories.where((s) => s.userId != user?.id).toList(),
      userDisplayName: user?.displayName ?? 'You',
      userAvatar:
          user?.avatar ?? 'https://picsum.photos/100/100?random=default-avatar',
      hasOtherStories: hasOtherStories,
    );

    // Reduce vertical padding at the bottom for phones
    final isSmallScreen = MediaQuery.of(context).size.height < 750;
    return Container(
      height: 115.responsive(context, min: 105, max: 125),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppSpacing.responsiveRadius(
          context,
          AppSpacing.radiusExtraLarge,
        ),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.standard.responsive(context),
          vertical: AppSpacing.tiny.responsive(context),
        ),
        children: cards,
      ),
    );
  }

  List<Widget> _buildStoryCards({
    required BuildContext context,
    required List<Story> userStories,
    required List<Story> otherStories,
    required String userDisplayName,
    required String userAvatar,
    required bool hasOtherStories,
  }) {
    final cards = <Widget>[];

    // Current user's story tile (always first)
    cards.add(
      StoryCard(
        username: userDisplayName,
        avatar: userAvatar,
        storyPreviewUrl: userStories.isNotEmpty
            ? _getStoryPreviewUrl(userStories.first)
            : null,
        backgroundColor: userStories.isNotEmpty
            ? userStories.first.backgroundColor
            : null,
        isTextStory:
            userStories.isNotEmpty && userStories.first.mediaType == 'text',
        isCurrentUser: true,
        isViewed: true,
        onTap: () {
          if (userStories.isEmpty) {
            _showCreateStoryDialog(context);
          } else {
            _openStoryViewer(context, userStories);
          }
        },
        onAddTap: () => _showCreateStoryDialog(context),
      ),
    );

    // Other users' stories
    for (final story in otherStories) {
      final authorName = story.author.displayName.isNotEmpty
          ? story.author.displayName
          : story.author.username;
      cards.add(
        StoryCard(
          username: authorName,
          avatar:
              story.author.avatar ??
              'https://picsum.photos/100/100?random=${story.userId.hashCode}',
          storyPreviewUrl: _getStoryPreviewUrl(story),
          backgroundColor: story.backgroundColor,
          isTextStory: story.mediaType == 'text',
          isViewed: story.isViewed,
          onTap: () {
            final provider = context.read<StoryProvider>();
            final userStories =
                provider.stories.where((s) => s.userId == story.userId).toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _openStoryViewer(
              context,
              userStories,
              initialIndex: userStories.indexWhere((s) => s.id == story.id),
            );
          },
        ),
      );
    }

    // Empty state hint
    if (!hasOtherStories) {
      cards.add(const SizedBox(width: 12));
      cards.add(
        Center(
          child: Text(
            'Stories from people you follow will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  void _openStoryViewer(
    BuildContext context,
    List<Story> stories, {
    int initialIndex = 0,
  }) {
    if (stories.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            StoryViewer(stories: stories, initialIndex: initialIndex),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _showCreateStoryDialog(BuildContext context) async {
    // Require full activation (verified + purchased ROO) to create stories
    final isActivated = await VerificationUtils.checkActivation(context);
    if (!isActivated) return;

    final List<MediaUploadResult> selectedMedia = [];
    bool isUploading = false;
    final captionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogStateCtx, setState) {
          final colors = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          Future<void> pickMediaFromGallery() async {
            setState(() {
              isUploading = true;
            });

            final result = await FileUploadUtils.pickAndUploadMediaList(
              context: context,
              bucket: SupabaseConfig.postMediaBucket,
            );

            if (!mounted) return;

            setState(() {
              isUploading = false;
              if (result.isNotEmpty) {
                selectedMedia.addAll(result);
              }
            });
          }

          Future<void> capturePhotoFromCamera() async {
            setState(() {
              isUploading = true;
            });

            try {
              final XFile? picked = await _imagePicker.pickImage(
                source: ImageSource.camera,
              );
              if (picked == null) {
                if (!mounted) return;
                setState(() => isUploading = false);
                return;
              }

              final file = File(picked.path);
              final uploaded = await _uploadStoryMediaFile(file);

              if (!mounted) return;
              setState(() {
                isUploading = false;
                if (uploaded != null) {
                  selectedMedia.add(uploaded);
                }
              });
            } catch (e) {
              if (!mounted) return;
              setState(() => isUploading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to capture photo: $e')),
              );
            }
          }

          int wordCount = captionController.text
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .length;
          bool canShare =
              selectedMedia.isNotEmpty ||
              (captionController.text.trim().isNotEmpty && wordCount <= 250);
          String? textError;
          if (captionController.text.trim().isNotEmpty && wordCount > 250) {
            textError = 'Text stories are limited to 250 words.';
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: colors.surface,
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            title: Row(
              children: [
                Text(
                  'Create Story',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.88,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.62,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : pickMediaFromGallery,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 200),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant.withValues(
                              alpha: 0.25,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.outlineVariant,
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              if (selectedMedia.isEmpty)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 42,
                                        color: colors.onSurface,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Click to upload',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Image or video (max 15s)',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 240,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.all(8),
                                      itemBuilder: (ctx, index) {
                                        final media = selectedMedia[index];
                                        return Stack(
                                          children: [
                                            Container(
                                              width: 220,
                                              decoration: BoxDecoration(
                                                color: Colors.black12,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: media.mediaType == 'video'
                                                  ? Container(
                                                      color: Colors.black
                                                          .withOpacity(0.75),
                                                      alignment:
                                                          Alignment.center,
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: const [
                                                          Icon(
                                                            Icons
                                                                .play_circle_fill,
                                                            color: Colors.white,
                                                            size: 42,
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'Video ready',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : Image.network(
                                                      media.url,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => Container(
                                                            color: Colors
                                                                .grey
                                                                .shade900,
                                                            alignment: Alignment
                                                                .center,
                                                            child: const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                    ),
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: IconButton(
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.black
                                                      .withOpacity(0.55),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(
                                                    32,
                                                    32,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                icon: const Icon(Icons.close),
                                                onPressed: isUploading
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          selectedMedia
                                                              .removeAt(index);
                                                        });
                                                      },
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
                                      itemCount: selectedMedia.length,
                                    ),
                                  ),
                                ),
                              if (selectedMedia.isNotEmpty)
                                Positioned(
                                  left: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${selectedMedia.length} item${selectedMedia.length == 1 ? '' : 's'} selected',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              if (isUploading)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isUploading
                                  ? null
                                  : pickMediaFromGallery,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isUploading
                                  ? null
                                  : capturePhotoFromCamera,
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: captionController,
                        decoration: InputDecoration(
                          hintText:
                              'Add a caption or share a text story (max 250 words)',
                          filled: true,
                          fillColor: colors.surfaceVariant.withValues(
                            alpha: 0.25,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          errorText: textError,
                        ),
                        minLines: 1,
                        maxLines: 8,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported: JPG, PNG, MP4, MOV. Videos should be 15s or less.\nYou can also share a text-only story (max 250 words).',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isUploading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: (!canShare || isUploading)
                    ? null
                    : () async {
                        setState(() {
                          isUploading = true;
                        });
                        final storyProvider = context.read<StoryProvider>();
                        final List<StoryMediaInput> mediaInputs = selectedMedia
                            .map(
                              (m) => StoryMediaInput(
                                url: m.url,
                                mediaType: m.mediaType,
                              ),
                            )
                            .toList();
                        final String? caption =
                            captionController.text.trim().isEmpty
                            ? null
                            : captionController.text.trim();
                        // If no media, treat as text-only story (pass empty list with textOverlay)
                        final success = await storyProvider.createStories(
                          mediaItems: mediaInputs,
                          caption: mediaInputs.isNotEmpty ? caption : null,
                          textOverlay: mediaInputs.isEmpty ? caption : null,
                          backgroundColor: mediaInputs.isEmpty
                              ? '#000000'
                              : null,
                        );
                        if (!mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success.isNotEmpty
                                  ? 'Story submitted. It will appear after verification.'
                                  : 'Failed to share story',
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    isUploading ? 'Uploading…' : 'Share Story',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<MediaUploadResult?> _uploadStoryMediaFile(File file) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('\\').last}';
      final bucket = SupabaseConfig.postMediaBucket;

      final response = await SupabaseService().client.storage
          .from(bucket)
          .upload(fileName, file);

      if (response.isEmpty) return null;

      final publicUrl = SupabaseService().client.storage
          .from(bucket)
          .getPublicUrl(fileName);
      return FileUploadUtils.mediaResult(
        url: publicUrl,
        fileExtension: extension,
      );
    } catch (e) {
      debugPrint('StoriesCarousel: Failed to upload camera media - $e');
      return null;
    }
  }

  Widget _mediaOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, color: colors.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.6),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _showImageEditor(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Image',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filterButton('Grayscale', Icons.filter_b_and_w, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'grayscale');
                  }),
                  _filterButton('Sepia', Icons.filter_vintage, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'sepia');
                  }),
                  _filterButton('Invert', Icons.invert_colors, () {
                    Navigator.pop(context);
                    _applyFilterToImage(index, 'invert');
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterButton(String label, IconData icon, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, color: colors.primary, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyFilterToImage(int index, String filterType) async {
    try {
      final imageFile = _selectedMediaFiles[index];
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image != null) {
        img.Image filteredImage;

        switch (filterType) {
          case 'grayscale':
            filteredImage = img.grayscale(image);
            break;
          case 'sepia':
            filteredImage = img.sepia(image);
            break;
          case 'invert':
            filteredImage = img.invert(image);
            break;
          default:
            filteredImage = image;
        }

        final filteredBytes = img.encodeJpg(filteredImage);
        final tempDir = await Directory.systemTemp.createTemp();
        final filteredFile = File(
          '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await filteredFile.writeAsBytes(filteredBytes);

        if (mounted) {
          setState(() {
            _selectedMediaFiles[index] = filteredFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply filter: $e')));
      }
    }
  }

  void _showVideoEditor(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Video',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filterButton('Trim', Icons.content_cut, () {
                    Navigator.pop(context);
                    _showVideoTrimDialog(index);
                  }),
                  _filterButton('Mute', Icons.volume_off, () {
                    Navigator.pop(context);
                    _muteVideo(index);
                  }),
                  _filterButton('Rotate', Icons.rotate_right, () {
                    Navigator.pop(context);
                    _rotateVideo(index);
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showVideoTrimDialog(int index) async {
    final videoFile = _selectedMediaFiles[index];
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (!mounted) return;

      double startTrim = 0.0;
      double endTrim = controller.value.duration.inMilliseconds.toDouble();

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Trim Video'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () {
                      setState(() {
                        controller!.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Text(
                        'Start: ${(startTrim / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Slider(
                        value: startTrim,
                        min: 0,
                        max: controller.value.duration.inMilliseconds
                            .toDouble(),
                        onChanged: (value) {
                          setState(() {
                            startTrim = value;
                            if (startTrim >= endTrim) {
                              endTrim = math.min(
                                startTrim + 1000,
                                controller!.value.duration.inMilliseconds
                                    .toDouble(),
                              );
                            }
                          });
                        },
                      ),
                      Text(
                        'End: ${(endTrim / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Slider(
                        value: endTrim,
                        min: 0,
                        max: controller.value.duration.inMilliseconds
                            .toDouble(),
                        onChanged: (value) {
                          setState(() {
                            endTrim = value;
                            if (endTrim <= startTrim) {
                              startTrim = math.max(0, endTrim - 1000);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Duration: ${((endTrim - startTrim) / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _applyVideoTrim(index, startTrim, endTrim);
                },
                child: const Text('Apply Trim'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
    } finally {
      controller?.dispose();
    }
  }

  Future<void> _applyVideoTrim(int index, double startMs, double endMs) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Video trimming simulation complete! (Full implementation requires FFmpeg)',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _muteVideo(int index) async {
    if (!mounted) return;

    final videoFile = _selectedMediaFiles[index];
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (!mounted) return;

      bool isMuted = false;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Mute Video'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            controller!.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            isMuted = !isMuted;
                            controller!.setVolume(isMuted ? 0.0 : 1.0);
                          });
                        },
                        icon: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                        ),
                        label: Text(isMuted ? 'Muted' : 'Audio On'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isMuted ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (isMuted && mounted) {
                    _videoMuteFlags[index] = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Video will be muted when posted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
    } finally {
      controller?.dispose();
    }
  }

  Future<void> _rotateVideo(int index) async {
    if (!mounted) return;

    final videoFile = _selectedMediaFiles[index];
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      if (!mounted) return;

      int rotationDegrees = 0;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Rotate Video'),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Transform.rotate(
                        angle: rotationDegrees * math.pi / 180,
                        child: AspectRatio(
                          aspectRatio: controller!.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            controller!.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            rotationDegrees = (rotationDegrees - 90) % 360;
                          });
                        },
                        icon: const Icon(Icons.rotate_left),
                        label: const Text('Left'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${rotationDegrees % 360}°',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            rotationDegrees = (rotationDegrees + 90) % 360;
                          });
                        },
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Right'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (rotationDegrees != 0 && mounted) {
                    _videoRotationFlags[index] = rotationDegrees;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Video will be rotated ${rotationDegrees % 360}° when posted',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
    } finally {
      controller?.dispose();
    }
  }

  String _resolveUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/$url';
  }

  /// Get preview URL for a story, returns null for text-only stories
  String? _getStoryPreviewUrl(Story story) {
    if (story.mediaType == 'text' || story.mediaUrl.isEmpty) {
      return null;
    }
    return _resolveUrl(story.mediaUrl);
  }
}

// Video Preview Widget
class _VideoPreviewWidget extends StatefulWidget {
  final File videoFile;

  const _VideoPreviewWidget({required this.videoFile});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _controller!,
      autoPlay: false,
      looping: false,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).colorScheme.primary,
        handleColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),
      placeholder: Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorBuilder: (context, errorMessage) {
        return Container(
          color: Colors.black,
          child: const Center(child: Icon(Icons.error, color: Colors.white)),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _chewieController == null) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Chewie(controller: _chewieController!);
  }
}


