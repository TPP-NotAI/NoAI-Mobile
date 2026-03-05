import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/feed_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/post.dart';
import '../../config/supabase_config.dart';
import '../../services/supabase_service.dart';

import 'package:rooverse/l10n/hardcoded_l10n.dart';
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
    _selectedTags = widget.post.tags?.map((t) => t.name).toList() ?? [];
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
      ).showSnackBar(SnackBar(content: Text('Failed to pick media: $e'.tr(context))));
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

  /// Shows a dialog when the edited post is detected as an advertisement.
  /// Returns true if the user paid the ad fee, false otherwise.
  Future<bool> _showAdFeeDialog(double adConfidence, String? adType) async {
    const double adFeeRoo = 5.0;

    if (!mounted) return false;

    final walletProvider = context.read<WalletProvider>();
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign_outlined, color: Color(0xFFFF8C00)),
            const SizedBox(width: 8),
            Text('Advertisement Detected'.tr(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our system detected this post as promotional content '
              '(${adConfidence.toStringAsFixed(0)}% confidence'
              '${adType != null ? " · ${adType.replaceAll('_', ' ')}" : ""}).',
            ),
            const SizedBox(height: 12),
            Text(
              'To publish it, an advertising fee is required.'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ad fee'.tr(context)),
                  Text(
                    '${adFeeRoo.toStringAsFixed(0)} ROO'.tr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'If you decline, your post will be held and you can pay later from your profile.'.tr(context),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now'.tr(context)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
            ),
            child: Text('Pay ${adFeeRoo.toStringAsFixed(0)} ROO'.tr(context)),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final success = await walletProvider.spendRoo(
        userId: userId,
        amount: adFeeRoo,
        activityType: 'AD_FEE',
        metadata: {
          'ad_confidence': adConfidence,
          'ad_type': adType,
        },
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient ROO balance to pay the advertising fee.'.tr(context),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return success;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'.tr(context)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _saveChanges() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _existingMedia.isEmpty && _newMediaFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post cannot be empty'.tr(context))));
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
        originalBody: widget.post.content,
        onAdFeeRequired: (adConfidence, adType) =>
            _showAdFeeDialog(adConfidence, adType),
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post updated successfully'.tr(context))),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update post'.tr(context))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'.tr(context))));
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
        title: Text('Edit Post'.tr(context)),
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
                : Text('Save'.tr(context)),
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
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?'.tr(context),
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
                                      : '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.postMediaBucket}/${media.storagePath}',
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
                  label: Text('Add Photo'.tr(context)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickMedia(fromCamera: false, isVideo: true),
                  icon: const Icon(Icons.videocam),
                  label: Text('Add Video'.tr(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
