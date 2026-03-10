import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';


/// Repository for handling media uploads and post_media operations.
class MediaRepository {
  final _client = SupabaseService().client;

  /// Upload a media file to Supabase Storage.
  ///
  /// Returns a record with:
  /// - [path]: the relative Supabase storage path, or null on failure.
  /// - [aiFile]: the compressed [File] to use for AI analysis (smaller = faster
  ///   AI check). Null if no compression was applied (use the original file).
  ///   The **caller must delete [aiFile]** once AI analysis is done.
  Future<({String? path, File? aiFile})> uploadMedia({
    required File file,
    required String userId,
    required String postId,
    required String mediaType, // 'image' or 'video'
    int index = 0,
    void Function(double progress)? onProgress,
  }) async {
    File uploadFile = file;
    File? compressedFile;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Compress video before upload (0–20% of progress bar)
      // Only attempt if file is over 10MB — smaller files rarely benefit.
      if (mediaType == 'video' && await file.length() > 10 * 1024 * 1024) {
        debugPrint('MediaRepository: Compressing video...');

        // Animate 0→18% while compression runs
        double compressProgress = 0.0;
        final compressTimer = onProgress == null ? null : Timer.periodic(
          const Duration(milliseconds: 300),
          (_) {
            if (compressProgress < 0.18) {
              compressProgress = (compressProgress + 0.01).clamp(0.0, 0.18);
              onProgress(compressProgress);
            }
          },
        );

        final origSize = await file.length();
        final info = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        compressTimer?.cancel();
        final compressedPath = info?.file?.path;

        if (compressedPath != null) {
          final candidate = File(compressedPath);
          final compSize = await candidate.length();
          final origMB = origSize / 1024 / 1024;
          final compMB = compSize / 1024 / 1024;
          debugPrint('MediaRepository: Compressed ${origMB.toStringAsFixed(1)}MB → ${compMB.toStringAsFixed(1)}MB');
          // Only use compressed file if it actually reduced the size
          if (compSize < origSize) {
            compressedFile = candidate;
            uploadFile = compressedFile;
            debugPrint('MediaRepository: Using compressed file (${((1 - compSize / origSize) * 100).toStringAsFixed(0)}% smaller)');
          } else {
            debugPrint('MediaRepository: Compression did not reduce size — using original');
            try { candidate.delete(); } catch (_) {}
          }
        }
        onProgress?.call(0.20);
      }

      final extension = uploadFile.path.split('.').last.toLowerCase();
      final fileName = '$timestamp-$index.$extension';
      final storagePath = '$postId/$userId/$fileName';
      final mimeType = getMimeType(extension, mediaType);

      if (onProgress != null) {
        // Upload covers 20–100% of progress bar
        await _uploadWithProgress(
          file: uploadFile,
          storagePath: storagePath,
          mimeType: mimeType,
          startProgress: mediaType == 'video' ? 0.20 : 0.0,
          onProgress: onProgress,
        );
      } else {
        await _client.storage
            .from(SupabaseConfig.postMediaBucket)
            .upload(
              storagePath,
              uploadFile,
              fileOptions: FileOptions(contentType: mimeType),
            )
            .timeout(const Duration(minutes: 10));
      }

      debugPrint('MediaRepository: Uploaded media to $storagePath');
      // Return the compressed file so the caller can pass it to AI detection.
      // Caller is responsible for deleting it after AI analysis completes.
      return (path: storagePath, aiFile: compressedFile);
    } catch (e) {
      debugPrint('MediaRepository: Error uploading media - $e');
      // Clean up compressed file on upload failure
      if (compressedFile != null) {
        try { await compressedFile.delete(); } catch (_) {}
      }
      return (path: null, aiFile: null);
    }
  }

  /// Uploads via the Supabase SDK while animating progress with a timer.
  /// [startProgress] is the value already reported (e.g. 0.20 after compression).
  Future<void> _uploadWithProgress({
    required File file,
    required String storagePath,
    required String mimeType,
    required void Function(double progress) onProgress,
    double startProgress = 0.0,
  }) async {
    final fileSize = await file.length();
    // Estimate duration: ~1 MB/s on a typical mobile connection.
    final estimatedSeconds = (fileSize / (1024 * 1024)).clamp(5.0, 540.0);
    // Animate from startProgress up to 95%, leaving the last 5% for server ack.
    final remaining = 0.95 - startProgress;
    double simulatedProgress = startProgress;
    const tickInterval = Duration(milliseconds: 300);
    final ticksTotal = estimatedSeconds * 1000 / tickInterval.inMilliseconds;
    final increment = remaining / ticksTotal;

    final timer = Timer.periodic(tickInterval, (_) {
      if (simulatedProgress < 0.95) {
        simulatedProgress = (simulatedProgress + increment).clamp(0.0, 0.95);
        onProgress(simulatedProgress);
      }
    });

    try {
      await _client.storage
          .from(SupabaseConfig.postMediaBucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: mimeType),
          )
          .timeout(const Duration(minutes: 10));
      timer.cancel();
      onProgress(1.0);
    } catch (e) {
      timer.cancel();
      rethrow;
    }
  }

  /// Create a post_media record in the database.
  Future<bool> createPostMedia({
    required String postId,
    required String mediaType,
    required String storagePath,
    String? mimeType,
    int? width,
    int? height,
    double? durationSeconds,
  }) async {
    try {
      await _client.from(SupabaseConfig.postMediaTable).insert({
        'post_id': postId,
        'media_type': mediaType,
        'storage_path': storagePath,
        'mime_type': mimeType,
        'width': width,
        'height': height,
        'duration_seconds': durationSeconds,
      });
      return true;
    } catch (e) {
      debugPrint('MediaRepository: Error creating post_media - $e');
      return false;
    }
  }

  /// Delete media from storage and database.
  Future<bool> deleteMedia(String mediaId) async {
    try {
      // First get the media record to get storage path
      final record = await _client
          .from(SupabaseConfig.postMediaTable)
          .select('storage_path')
          .eq('id', mediaId)
          .maybeSingle();

      if (record != null) {
        final storagePath = record['storage_path'] as String;
        // Remove from storage
        await _client.storage
            .from(SupabaseConfig.postMediaBucket)
            .remove([storagePath]);
      }

      // Delete from database
      await _client
          .from(SupabaseConfig.postMediaTable)
          .delete()
          .eq('id', mediaId);
      return true;
    } catch (e) {
      debugPrint('MediaRepository: Error deleting media - $e');
      return false;
    }
  }

  String getMimeType(String extension, String mediaType) {
    if (mediaType == 'video') {
      switch (extension) {
        case 'mp4':
          return 'video/mp4';
        case 'mov':
          return 'video/quicktime';
        case 'avi':
          return 'video/x-msvideo';
        case 'webm':
          return 'video/webm';
        default:
          return 'video/mp4';
      }
    } else {
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'gif':
          return 'image/gif';
        case 'webp':
          return 'image/webp';
        case 'heic':
          return 'image/heic';
        default:
          return 'image/jpeg';
      }
    }
  }
}
