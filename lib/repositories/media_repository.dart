import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/supabase_service.dart';

/// Repository for handling media uploads and post_media operations.
class MediaRepository {
  final _client = SupabaseService().client;

  /// Upload a media file to Supabase Storage and return the relative storage path.
  Future<String?> uploadMedia({
    required File file,
    required String userId,
    required String postId,
    required String mediaType, // 'image' or 'video'
    int index = 0,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last.toLowerCase();
      final fileName = '$timestamp-$index.$extension';
      final storagePath = '$postId/$userId/$fileName';

      // Upload to Supabase Storage bucket configured for post media
      await _client.storage
          .from(SupabaseConfig.postMediaBucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: getMimeType(extension, mediaType),
            ),
          );

      debugPrint('MediaRepository: Uploaded media to $storagePath');
      // Return the relative storage path (not full URL)
      // The display layer constructs the full public URL from this path
      return storagePath;
    } catch (e) {
      debugPrint('MediaRepository: Error uploading media - $e');
      return null;
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
