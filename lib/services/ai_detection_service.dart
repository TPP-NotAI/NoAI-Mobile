import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_detection_result.dart';
import '../models/moderation_result.dart';

/// Singleton service for the NOAI AI Content Detection and Moderation API.
class AiDetectionService {
  static const String _baseUrl = 'https://detectorllm.rooverse.app';
  static const Duration _timeout = Duration(seconds: 60);
  static const Duration _mediaTimeout = Duration(minutes: 10);

  /// Files larger than this go through the chunked upload API (matches server).
  static const int _chunkThresholdBytes = 25 * 1024 * 1024; // 25 MB
  static const int _chunkSizeBytes = 20 * 1024 * 1024; // 20 MB per chunk

  static final AiDetectionService _instance = AiDetectionService._internal();
  factory AiDetectionService() => _instance;
  AiDetectionService._internal();

  // --- AI Detection Endpoints ---

  /// Analyse text content for AI generation.
  Future<AiDetectionResult?> detectText(
    String content, {
    String models = 'gpt-5.2,o3',
    bool includeRaw = false,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/text'),
      );
      request.fields['content'] = content;
      request.fields['models'] = models;
      if (includeRaw) request.fields['include_raw'] = 'true';

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_timeout);
      final parsed = _parseResponse(response);
      if (parsed != null) return parsed;

      // Fallback: some deployments parse text detection as JSON body.
      return await _detectTextJsonFallback(
        content,
        models: models,
        includeRaw: includeRaw,
      );
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting text - $e');
      // Retry once using JSON payload before failing hard.
      return await _detectTextJsonFallback(
        content,
        models: models,
        includeRaw: includeRaw,
      );
    }
  }

  Future<AiDetectionResult?> _detectTextJsonFallback(
    String content, {
    required String models,
    required bool includeRaw,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/detect/text'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'content': content,
              'models': models,
              if (includeRaw) 'include_raw': true,
            }),
          )
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      debugPrint('AiDetectionService: Text JSON fallback failed - $e');
      return null;
    }
  }

  /// Analyse an image or video file for AI generation.
  Future<AiDetectionResult?> detectImage(
    File file, {
    String models = 'gpt-4.1',
    bool includeRaw = false,
  }) async {
    try {
      debugPrint(
        'AiDetectionService: Starting image detection for ${file.path}',
      );

      if (!await file.exists()) {
        debugPrint('AiDetectionService: Error - File does not exist');
        return null;
      }

      final fileSize = await file.length();
      debugPrint('AiDetectionService: File size: $fileSize bytes');

      final extension = file.path.split('.').last.toLowerCase();
      final isVideo = <String>{
        'mp4',
        'mov',
        'm4v',
        'webm',
        'avi',
        'mkv',
      }.contains(extension);
      final timeout = isVideo ? _mediaTimeout : _timeout;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/image'),
      );
      request.fields['models'] = models;
      if (includeRaw) request.fields['include_raw'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      debugPrint('AiDetectionService: Sending request to /detect/image...');
      final streamedResponse = await request.send().timeout(timeout);
      debugPrint('AiDetectionService: Request sent, waiting for response...');
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      debugPrint(
        'AiDetectionService: Received response ${response.statusCode}',
      );
      final result = _parseResponse(response);

      if (result != null) {
        debugPrint('AiDetectionService: Analysis ID: ${result.analysisId}');
        if (result.metadataAnalysis?.signals.isNotEmpty ?? false) {
          debugPrint(
            'AiDetectionService: Metadata signals: ${result.metadataAnalysis?.signals}',
          );
        }
      }

      return result;
    } on TimeoutException catch (e) {
      debugPrint('AiDetectionService: Image detection timed out - $e');
      rethrow;
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting image - $e');
      return null;
    }
  }

  /// Analyse mixed content (text + media file) for AI generation.
  Future<AiDetectionResult?> detectMixed(
    String content,
    File file, {
    String models = 'gpt-4.1',
    bool includeRaw = false,
  }) async {
    try {
      debugPrint('AiDetectionService: Starting mixed detection');

      if (!await file.exists()) {
        debugPrint('AiDetectionService: Error - File does not exist');
        return null;
      }

      final extension = file.path.split('.').last.toLowerCase();
      final isVideo = <String>{
        'mp4',
        'mov',
        'm4v',
        'webm',
        'avi',
        'mkv',
      }.contains(extension);
      final timeout = isVideo ? _mediaTimeout : _timeout;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/mixed'),
      );
      request.fields['content'] = content;
      request.fields['models'] = models;
      if (includeRaw) request.fields['include_raw'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      debugPrint('AiDetectionService: Sending request to /detect/mixed...');
      final streamedResponse = await request.send().timeout(timeout);
      debugPrint('AiDetectionService: Request sent, waiting for response...');
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      debugPrint(
        'AiDetectionService: Received response ${response.statusCode}',
      );
      final result = _parseResponse(response);

      if (result != null) {
        debugPrint('AiDetectionService: Analysis ID: ${result.analysisId}');
        if (result.metadataAnalysis?.signals.isNotEmpty ?? false) {
          debugPrint(
            'AiDetectionService: Metadata signals: ${result.metadataAnalysis?.signals}',
          );
        }
      }

      return result;
    } on TimeoutException catch (e) {
      debugPrint('AiDetectionService: Mixed detection timed out - $e');
      rethrow;
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting mixed content - $e');
      return null;
    }
  }

  // --- Full Combined Endpoint (Recommended) ---

  /// Runs AI detection + Content Moderation + Advertisement detection in a
  /// single parallel call. Use this instead of the individual endpoints.
  ///
  /// Pass [content] for text, [file] for media, or both.
  /// Files > 25 MB are automatically uploaded via the chunked upload API.
  Future<AiDetectionResult?> detectFull({
    String? content,
    File? file,
    String models = 'gpt-5.2,o3',
  }) async {
    assert(
      content != null || file != null,
      'detectFull: provide content, file, or both',
    );

    try {
      // Route large files through the chunked upload API.
      if (file != null && await file.length() > _chunkThresholdBytes) {
        debugPrint(
          'AiDetectionService: File exceeds ${_chunkThresholdBytes ~/ (1024 * 1024)} MB, '
          'using chunked upload.',
        );
        return await _detectFullChunked(file: file, content: content, models: models);
      }

      final extension = file?.path.split('.').last.toLowerCase() ?? '';
      final isVideo = <String>{
        'mp4',
        'mov',
        'm4v',
        'webm',
        'avi',
        'mkv',
      }.contains(extension);
      final timeout = isVideo ? _mediaTimeout : _timeout;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/full'),
      );
      request.fields['models'] = models;
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      debugPrint('AiDetectionService: Sending request to /detect/full...');
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      debugPrint(
        'AiDetectionService: /detect/full response ${response.statusCode}',
      );
      return _parseResponse(response);
    } on TimeoutException catch (e) {
      debugPrint('AiDetectionService: /detect/full timed out - $e');
      rethrow;
    } catch (e) {
      debugPrint('AiDetectionService: /detect/full error - $e');
      return null;
    }
  }

  /// Uploads a large file in 20 MB chunks then triggers detection.
  /// Flow: POST /upload/init → POST /upload/chunk (×N) → POST /upload/complete
  Future<AiDetectionResult?> _detectFullChunked({
    required File file,
    String? content,
    required String models,
  }) async {
    try {
      final fileSize = await file.length();
      final fileName = file.path.split(Platform.pathSeparator).last;
      final extension = fileName.split('.').last.toLowerCase();
      final isVideo = <String>{
        'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv',
      }.contains(extension);
      final mimeType = isVideo ? 'video/$extension' : 'image/$extension';

      // 1. Init
      debugPrint(
        'AiDetectionService: chunked init – file=$fileName size=$fileSize',
      );
      final initReq = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/upload/init'),
      );
      initReq.fields['filename'] = fileName;
      initReq.fields['total_size'] = fileSize.toString();
      initReq.fields['content_type'] = mimeType;
      final initStream = await initReq.send().timeout(_timeout);
      final initResp = await http.Response.fromStream(initStream).timeout(_timeout);
      if (initResp.statusCode != 200) {
        debugPrint(
          'AiDetectionService: chunked init failed ${initResp.statusCode} – ${initResp.body}',
        );
        return null;
      }
      final uploadId = (json.decode(initResp.body) as Map<String, dynamic>)['upload_id'] as String;
      debugPrint('AiDetectionService: chunked upload_id=$uploadId');

      // 2. Chunks
      final raf = await file.open();
      int chunkIndex = 0;
      int offset = 0;
      try {
        while (offset < fileSize) {
          final remaining = fileSize - offset;
          final chunkLen = remaining < _chunkSizeBytes ? remaining : _chunkSizeBytes;
          final bytes = await raf.read(chunkLen);
          offset += bytes.length;

          final chunkReq = http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/api/v1/upload/chunk'),
          );
          chunkReq.fields['upload_id'] = uploadId;
          chunkReq.fields['chunk_index'] = chunkIndex.toString();
          chunkReq.files.add(http.MultipartFile.fromBytes(
            'chunk',
            bytes,
            filename: 'chunk_$chunkIndex',
          ));

          debugPrint(
            'AiDetectionService: sending chunk $chunkIndex '
            '(${bytes.length} bytes, offset $offset/$fileSize)',
          );
          final chunkStream = await chunkReq.send().timeout(_mediaTimeout);
          final chunkResp = await http.Response.fromStream(chunkStream).timeout(_mediaTimeout);
          if (chunkResp.statusCode != 200) {
            debugPrint(
              'AiDetectionService: chunk $chunkIndex failed '
              '${chunkResp.statusCode} – ${chunkResp.body}',
            );
            return null;
          }
          chunkIndex++;
        }
      } finally {
        await raf.close();
      }

      // 3. Complete
      debugPrint('AiDetectionService: chunked complete – $chunkIndex chunks sent');
      final completeReq = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/upload/complete'),
      );
      completeReq.fields['upload_id'] = uploadId;
      completeReq.fields['models'] = models;
      if (content != null && content.isNotEmpty) {
        completeReq.fields['content'] = content;
      }
      final completeStream = await completeReq.send().timeout(_mediaTimeout);
      final completeResp = await http.Response.fromStream(completeStream).timeout(_mediaTimeout);
      debugPrint(
        'AiDetectionService: chunked complete response ${completeResp.statusCode}',
      );
      return _parseResponse(completeResp);
    } on TimeoutException catch (e) {
      debugPrint('AiDetectionService: chunked upload timed out - $e');
      rethrow;
    } catch (e) {
      debugPrint('AiDetectionService: chunked upload error - $e');
      return null;
    }
  }

  // --- Moderation Endpoints (New) ---

  /// Check text for harmful content (hate speech, harassment, etc.).
  Future<ModerationResult?> moderateText(String content) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/moderate/text'),
      );
      request.fields['content'] = content;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ModerationResult.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('AiDetectionService: Error moderating text - $e');
      return null;
    }
  }

  /// Check image content for harmful material including nudity, violence, etc.
  Future<ModerationResult?> moderateImage(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/moderate/image'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ModerationResult.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('AiDetectionService: Error moderating image - $e');
      return null;
    }
  }

  /// Check video content by analyzing sample frames.
  Future<ModerationResult?> moderateVideo(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/moderate/video'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(_mediaTimeout);
      final response = await http.Response.fromStream(streamedResponse).timeout(_mediaTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ModerationResult.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('AiDetectionService: Error moderating video - $e');
      return null;
    }
  }

  // --- Utility Endpoints ---

  /// Check whether the NOAI API is reachable.
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/health'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AiDetectionService: Health check failed - $e');
      return false;
    }
  }

  /// Submit feedback to the NOAI learning system after a moderation decision.
  Future<bool> submitFeedback({
    required String analysisId,
    required String correctResult,
    String? feedbackNotes,
    String source = 'moderator',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'analysis_id': analysisId,
          'correct_result': correctResult,
          'feedback_notes': feedbackNotes,
          'source': source,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('AiDetectionService: Feedback submitted for $analysisId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AiDetectionService: Error submitting feedback - $e');
      return false;
    }
  }

  AiDetectionResult? _parseResponse(http.Response response) {
    debugPrint('AiDetectionService: Raw response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final parsed = AiDetectionResult.fromJson(data);
      debugPrint(
        'AiDetectionService: Parsed result=${parsed.result}, '
        'confidence=${parsed.confidence}, analysisId=${parsed.analysisId}',
      );
      return parsed;
    }
    // 413 means the file is too large for the detection server's current
    // upload limit. We cannot analyse it, so we pass it through as human-
    // generated rather than blocking the post or silently returning null.
    if (response.statusCode == 413) {
      debugPrint(
        'AiDetectionService: 413 – file too large for detection server, '
        'treating as HUMAN-GENERATED (pass-through).',
      );
      return AiDetectionResult(
        result: 'HUMAN-GENERATED',
        confidence: 0.0,
        analysisId: 'skipped_413',
        contentType: 'unknown',
        rationale: 'File too large for AI detection – passed through.',
      );
    }
    debugPrint(
      'AiDetectionService: API returned ${response.statusCode} - ${response.body}',
    );
    return null;
  }
}
