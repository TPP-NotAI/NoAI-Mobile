import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_detection_result.dart';
import '../models/moderation_result.dart';

/// Singleton service for the NOAI AI Content Detection and Moderation API.
class AiDetectionService {
  static const String _baseUrl = 'https://noai-lm-production.up.railway.app';

  static final AiDetectionService _instance = AiDetectionService._internal();
  factory AiDetectionService() => _instance;
  AiDetectionService._internal();

  // --- AI Detection Endpoints ---

  /// Analyse text content for AI generation.
  Future<AiDetectionResult?> detectText(String content) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/text'),
      );
      request.fields['content'] = content;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _parseResponse(response);
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting text - $e');
      return null;
    }
  }

  /// Analyse an image or video file for AI generation.
  Future<AiDetectionResult?> detectImage(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/image'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _parseResponse(response);
    } catch (e) {
      debugPrint('AiDetectionService: Error detecting image - $e');
      return null;
    }
  }

  /// Analyse mixed content (text + media file) for AI generation.
  Future<AiDetectionResult?> detectMixed(String content, File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/detect/mixed'),
      );
      request.fields['content'] = content;
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _parseResponse(response);
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
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

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
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

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
