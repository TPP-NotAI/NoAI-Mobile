/// Response model for the NOAI AI Detection API.
class AiDetectionResult {
  final String analysisId;
  final String
  result; // "AI-GENERATED", "LIKELY AI-GENERATED", "LIKELY HUMAN-GENERATED", "HUMAN-GENERATED"
  final double confidence; // 0-100
  final String contentType; // "text", "image", "mixed"
  final List<dynamic>? modelAnalyses;

  AiDetectionResult({
    required this.analysisId,
    required this.result,
    required this.confidence,
    required this.contentType,
    this.modelAnalyses,
  });

  factory AiDetectionResult.fromJson(Map<String, dynamic> json) {
    return AiDetectionResult(
      analysisId: json['analysis_id'] as String? ?? '',
      result: json['final_result'] as String? ?? 'HUMAN-GENERATED',
      confidence: (json['final_confidence'] as num?)?.toDouble() ?? 0.0,
      contentType: json['content_type'] as String? ?? '',
      modelAnalyses: json['model_analyses'] as List<dynamic>?,
    );
  }
}
