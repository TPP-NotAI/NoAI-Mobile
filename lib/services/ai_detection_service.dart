import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_detection_result.dart';
import '../models/moderation_result.dart';

/// Singleton service for the NOAI AI Content Detection and Moderation API.
class AiDetectionService {
  static const String _baseUrl = 'https://noai-lm-production.up.railway.app';
  static const Duration _timeout = Duration(seconds: 60);

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
      return _parseResponse(response);
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting text - $e');
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

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/image'),
      );
      request.fields['models'] = models;
      if (includeRaw) request.fields['include_raw'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      debugPrint('AiDetectionService: Sending request to /detect/image...');
      final streamedResponse = await request.send().timeout(_timeout);
      debugPrint('AiDetectionService: Request sent, waiting for response...');
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_timeout);

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

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/mixed'),
      );
      request.fields['content'] = content;
      request.fields['models'] = models;
      if (includeRaw) request.fields['include_raw'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      debugPrint('AiDetectionService: Sending request to /detect/mixed...');
      final streamedResponse = await request.send().timeout(_timeout);
      debugPrint('AiDetectionService: Request sent, waiting for response...');
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_timeout);

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
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting mixed content - $e');
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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
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
      return AiDetectionResult.fromJson(data);
    }
    debugPrint(
      'AiDetectionService: API returned ${response.statusCode} - ${response.body}',
    );
    return null;
  }
}
