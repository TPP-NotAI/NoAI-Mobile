import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/feed_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/post.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;

  // Media state
  List<PostMedia> _existingMedia = [];
  final List<String> _deletedMediaIds = [];
  final List<File> _newMediaFiles = [];
  final List<String> _newMediaTypes = []; // 'image' or 'video'

  // Location state
  late String? _selectedLocation;

  // Tags/Topics state - (Simplified: reusing string list, neglecting complex tag objects for now or assuming just names)
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _existingMedia = List.from(widget.post.mediaList ?? []);
    _selectedLocation = widget.post.location;
    // Map PostTag objects to strings
    _selectedTags = widget.post.tags?.map((t) => t.tag).toList() ?? [];
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({
    required bool fromCamera,
    required bool isVideo,
  }) async {
    try {
      final XFile? file = isVideo
          ? await _imagePicker.pickVideo(
              source: fromCamera ? ImageSource.camera : ImageSource.gallery,
            )
          : await _imagePicker.pickImage(
              source: fromCamera ? ImageSource.camera : ImageSource.gallery,
            );

      if (file != null) {
        setState(() {
          _newMediaFiles.add(File(file.path));
          _newMediaTypes.add(isVideo ? 'video' : 'image');
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick media: $e')));
    }
  }

  void _removeExistingMedia(int index) {
    setState(() {
      final media = _existingMedia[index];
      _deletedMediaIds.add(media.id);
      _existingMedia.removeAt(index);
    });
  }

  void _removeNewMedia(int index) {
    setState(() {
      _newMediaFiles.removeAt(index);
      _newMediaTypes.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _existingMedia.isEmpty && _newMediaFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post cannot be empty')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final feedProvider = context.read<FeedProvider>();
      final success = await feedProvider.updatePostWithMedia(
        postId: widget.post.id,
        body: text,
        location: _selectedLocation,
        deletedMediaIds: _deletedMediaIds,
        newMediaFiles: _newMediaFiles,
        newMediaTypes: _newMediaTypes,
        // Tags not supported in updatePostWithMedia yet?
        // PostRepository.updatePost doesn't assume tags update.
        // We'll ignore tags update for now or add it later if needed.
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update post')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<UserProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        actions: [
          FilledButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info (static)
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: user?.avatar != null
                      ? NetworkImage(user!.avatar!)
                      : null,
                  child: user?.avatar == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Text(
                  user?.displayName ?? 'You',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Text Input
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 5,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),

            // Media List
            if (_existingMedia.isNotEmpty || _newMediaFiles.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Existing Media
                    ..._existingMedia.asMap().entries.map((entry) {
                      final index = entry.key;
                      final media = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.network(
                                  // Assuming full URL or using primaryMediaUrl logic helper
                                  media.storagePath.startsWith('http')
                                      ? media.storagePath
                                      : 'https://your-project-url.supabase.co/storage/v1/object/public/media/${media.storagePath}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey,
                                        child: const Icon(Icons.error),
                                      ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeExistingMedia(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (media.mediaType == 'video')
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    // New Media
                    ..._newMediaFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final isVideo = _newMediaTypes[index] == 'video';
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: isVideo
                                    ? Container(
                                        color: Colors.black,
                                      ) // Placeholder for video file
                                    : Image.file(file, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeNewMedia(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (isVideo)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Add Media Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _pickMedia(fromCamera: false, isVideo: false),
                  icon: const Icon(Icons.photo),
                  label: const Text('Add Photo'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickMedia(fromCamera: false, isVideo: true),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Add Video'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
