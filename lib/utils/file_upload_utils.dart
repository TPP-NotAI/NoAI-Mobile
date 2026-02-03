import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';

/// Utility class for handling file uploads to Supabase storage.
class FileUploadUtils {
  static final SupabaseClient _client = SupabaseService().client;

  /// Structured response for a media upload.
  /// Keeps both the public URL and whether it is an image or a video.
  static const _videoExtensions = {
    'mp4',
    'mov',
    'avi',
    'webm',
    'mkv',
  };

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
  };

  static bool _isVideo(String extension) =>
      _videoExtensions.contains(extension.toLowerCase());

  static bool _isImage(String extension) =>
      _imageExtensions.contains(extension.toLowerCase());

  /// Container object for the chosen upload.
  static MediaUploadResult mediaResult({
    required String url,
    required String fileExtension,
  }) {
    final isVideo = _isVideo(fileExtension);
    return MediaUploadResult(
      url: url,
      mediaType: isVideo ? 'video' : 'image',
    );
  }

  /// Pick an image from gallery or camera and upload to Supabase storage.
  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    required String bucket,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      // Upload to Supabase storage
      final response = await _client.storage
          .from(bucket)
          .upload(fileName, file);

      if (response.isNotEmpty) {
        // Get public URL
        final publicUrl = _client.storage.from(bucket).getPublicUrl(fileName);
        return publicUrl;
      }

      return null;
    } catch (e) {
      debugPrint('FileUploadUtils: Failed to upload image - $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      return null;
    }
  }

  /// Pick a video file and upload to Supabase storage.
  static Future<String?> pickAndUploadVideo({
    required BuildContext context,
    required String bucket,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = File(result.files.first.path!);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${result.files.first.name}';

      // Upload to Supabase storage
      final response = await _client.storage
          .from(bucket)
          .upload(fileName, file);

      if (response.isNotEmpty) {
        // Get public URL
        final publicUrl = _client.storage.from(bucket).getPublicUrl(fileName);
        return publicUrl;
      }

      return null;
    } catch (e) {
      debugPrint('FileUploadUtils: Failed to upload video - $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload video: $e')));
      return null;
    }
  }

  /// Single-step picker for image or video (no extra dialogs).
  /// Returns the public URL and media type string: `image` or `video`.
  static Future<MediaUploadResult?> pickAndUploadMedia({
    required BuildContext context,
    required String bucket,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: [
          ..._imageExtensions,
          ..._videoExtensions,
        ],
      );

      if (result == null || result.files.isEmpty) return null;

      final file = File(result.files.first.path!);
      final ext = (result.files.first.extension ?? '').toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.first.name}';

      final response = await _client.storage
          .from(bucket)
          .upload(fileName, file);

      if (response.isNotEmpty) {
        final publicUrl = _client.storage.from(bucket).getPublicUrl(fileName);
        return mediaResult(url: publicUrl, fileExtension: ext);
      }

      return null;
    } catch (e) {
      debugPrint('FileUploadUtils: Failed to upload media - $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload media: $e')));
      return null;
    }
  }

  /// Multi-select version: pick multiple media files and upload each.
  static Future<List<MediaUploadResult>> pickAndUploadMediaList({
    required BuildContext context,
    required String bucket,
  }) async {
    final uploads = <MediaUploadResult>[];
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: [
          ..._imageExtensions,
          ..._videoExtensions,
        ],
      );

      if (result == null || result.files.isEmpty) return uploads;

      for (final file in result.files) {
        if (file.path == null) continue;
        final path = file.path!;
        final ext = (file.extension ?? '').toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

        final response = await _client.storage
            .from(bucket)
            .upload(fileName, File(path));

        if (response.isNotEmpty) {
          final publicUrl = _client.storage.from(bucket).getPublicUrl(fileName);
          uploads.add(mediaResult(url: publicUrl, fileExtension: ext));
        }
      }
      return uploads;
    } catch (e) {
      debugPrint('FileUploadUtils: Failed to upload media list - $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload media: $e')));
      return uploads;
    }
  }

  /// Show dialog to choose between image and video upload.
  static Future<String?> showMediaPickerDialog({
    required BuildContext context,
    required String bucket,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Media Type'),
        content: const Text(
          'What type of media would you like to add to your story?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('image'),
            child: const Text('Photo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('video'),
            child: const Text('Video'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == null) return null;

    if (result == 'image') {
      return await showImageSourceDialog(context: context, bucket: bucket);
    } else {
      return await pickAndUploadVideo(context: context, bucket: bucket);
    }
  }

  /// Show dialog to choose image source (camera or gallery).
  static Future<String?> showImageSourceDialog({
    required BuildContext context,
    required String bucket,
  }) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Image Source'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (source == null) return null;

    return await pickAndUploadImage(
      context: context,
      bucket: bucket,
      source: source,
    );
  }
}

class MediaUploadResult {
  final String url;
  /// Either `image` or `video`.
  final String mediaType;

  const MediaUploadResult({
    required this.url,
    required this.mediaType,
  });
}
