import 'moderation_result.dart';

/// Response model for the NOAI AI Detection API.
class AiDetectionResult {
  final String analysisId;

  /// Classification: "AI-GENERATED", "LIKELY AI-GENERATED",
  /// "LIKELY HUMAN-GENERATED", "HUMAN-GENERATED"
  final String result;
  final double confidence; // 0-100
  final String contentType; // "text", "image", "mixed"
  final String? consensusStrength; // "strong", "moderate", "weak", "split"
  final String? rationale;
  final List<String>? combinedEvidence;
  final List<dynamic>? modelAnalyses;
  final ModerationResult? moderation;
  final double? safetyScore;

  AiDetectionResult({
    required this.analysisId,
    required this.result,
    required this.confidence,
    required this.contentType,
    this.consensusStrength,
    this.rationale,
    this.combinedEvidence,
    this.modelAnalyses,
    this.moderation,
    this.safetyScore,
  });

  factory AiDetectionResult.fromJson(Map<String, dynamic> json) {
    return AiDetectionResult(
      analysisId: json['analysis_id'] as String? ?? '',
      result: json['result'] as String? ?? 'HUMAN-GENERATED',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      contentType: json['content_type'] as String? ?? '',
      consensusStrength: json['consensus_strength'] as String?,
      rationale: json['rationale'] as String?,
      combinedEvidence: (json['combined_evidence'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      modelAnalyses: json['model_analyses'] as List<dynamic>?,
      moderation: json['moderation'] != null
          ? ModerationResult.fromJson(json['moderation'] as Map<String, dynamic>)
          : null,
      safetyScore: (json['safety_score'] as num?)?.toDouble(),
    );
  }
}
