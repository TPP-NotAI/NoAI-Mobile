import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_detection_result.dart';

/// Singleton service for the NOAI AI Content Detection API.
class AiDetectionService {
  static const String _baseUrl =
      'https://noai-lm-production.up.railway.app';

  static final AiDetectionService _instance = AiDetectionService._internal();
  factory AiDetectionService() => _instance;
  AiDetectionService._internal();

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

  /// Check whether the NOAI API is reachable.
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AiDetectionService: Health check failed - $e');
      return false;
    }
  }

  /// Submit feedback to the NOAI learning system after a moderation decision.
  ///
  /// [analysisId] is the UUID from the original detection response.
  /// [correctResult] should be one of: "HUMAN-GENERATED", "AI-GENERATED",
  ///   "LIKELY HUMAN-GENERATED", "LIKELY AI-GENERATED".
  /// [source] identifies who provided the feedback (e.g. "moderator", "user").
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
      debugPrint(
        'AiDetectionService: Feedback failed ${response.statusCode} - ${response.body}',
      );
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
