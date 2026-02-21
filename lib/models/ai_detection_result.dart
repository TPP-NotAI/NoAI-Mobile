import 'moderation_result.dart';

/// Advertisement detection result from /api/v1/detect/full
class AdvertisementResult {
  final bool detected;
  final double confidence; // 0-100
  final String? type; // e.g. "product_promotion", "service_ad"
  final List<String> evidence;
  final String? rationale;

  /// Platform action: "allow" | "flag_for_review" | "require_payment"
  final String action;

  AdvertisementResult({
    required this.detected,
    required this.confidence,
    this.type,
    required this.evidence,
    this.rationale,
    required this.action,
  });

  bool get requiresPayment => action == 'require_payment';
  bool get flaggedForReview => action == 'flag_for_review';

  factory AdvertisementResult.fromJson(Map<String, dynamic> json) {
    return AdvertisementResult(
      detected: json['detected'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String?,
      evidence:
          (json['evidence'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rationale: json['rationale'] as String?,
      action: json['action'] as String? ?? 'allow',
    );
  }

  Map<String, dynamic> toJson() => {
    'detected': detected,
    'confidence': confidence,
    'type': type,
    'evidence': evidence,
    'rationale': rationale,
    'action': action,
  };
}

/// Response model for the NOAI AI Detection API.
class AiDetectionResult {
  final String analysisId;

  /// Classification: "AI-GENERATED", "LIKELY AI-GENERATED",
  /// "LIKELY HUMAN-GENERATED", "HUMAN-GENERATED"
  final String result;
  final double confidence; // 0-100
  final String contentType; // "text", "image", "mixed"
  final String? consensusStrength;
  final String? rationale;
  final List<String>? combinedEvidence;
  final MetadataAnalysis? metadataAnalysis;
  final List<ModelResult>? modelResults;
  final ModerationResult? moderation;
  final double? safetyScore;
  final AdvertisementResult? advertisement;

  AiDetectionResult({
    required this.analysisId,
    required this.result,
    required this.confidence,
    required this.contentType,
    this.consensusStrength,
    this.rationale,
    this.combinedEvidence,
    this.metadataAnalysis,
    this.modelResults,
    this.moderation,
    this.safetyScore,
    this.advertisement,
  });

  factory AiDetectionResult.fromJson(Map<String, dynamic> json) {
    // API might return 'result' or 'final_result'
    final String rawResult =
        (json['final_result'] as String? ??
                json['result'] as String? ??
                'HUMAN-GENERATED')
            .trim()
            .toUpperCase();

    // API might return 'confidence' or 'final_confidence'
    final double rawConf =
        (json['final_confidence'] as num? ?? json['confidence'] as num? ?? 0.0)
            .toDouble();

    // Some models return 0.0-1.0, some 0-100. Normalize to 0-100.
    // NOTE: 0.0 is ambiguous, but we treat it as 0.0.
    final double normalizedConf = rawConf <= 1.0 && rawConf > 0
        ? rawConf * 100
        : rawConf;

    return AiDetectionResult(
      analysisId: json['analysis_id'] as String? ?? '',
      result: rawResult,
      confidence: normalizedConf,
      contentType: json['content_type'] as String? ?? '',
      consensusStrength: json['consensus_strength'] as String?,
      rationale:
          json['rationale'] as String? ?? json['final_rationale'] as String?,
      combinedEvidence: (json['combined_evidence'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      metadataAnalysis: json['metadata_analysis'] != null
          ? MetadataAnalysis.fromJson(
              json['metadata_analysis'] as Map<String, dynamic>,
            )
          : null,
      modelResults:
          ((json['model_results'] as List<dynamic>?) ??
                  (json['model_analyses'] as List<dynamic>?))
              ?.map((e) => ModelResult.fromJson(e as Map<String, dynamic>))
              .toList(),
      moderation: json['moderation'] != null
          ? ModerationResult.fromJson(
              json['moderation'] as Map<String, dynamic>,
            )
          : null,
      safetyScore: (json['safety_score'] as num?)?.toDouble(),
      advertisement: json['advertisement'] != null
          ? AdvertisementResult.fromJson(
              json['advertisement'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysis_id': analysisId,
      'result': result,
      'confidence': confidence,
      'content_type': contentType,
      'consensus_strength': consensusStrength,
      'rationale': rationale,
      'combined_evidence': combinedEvidence,
      'metadata_analysis': metadataAnalysis?.toJson(),
      'model_results': modelResults?.map((e) => e.toJson()).toList(),
      'moderation': moderation?.toJson(),
      'safety_score': safetyScore,
      'advertisement': advertisement?.toJson(),
    };
  }
}

class MetadataAnalysis {
  final double? adjustment;
  final List<String> signals;

  MetadataAnalysis({this.adjustment, required this.signals});

  factory MetadataAnalysis.fromJson(Map<String, dynamic> json) {
    return MetadataAnalysis(
      adjustment: (json['adjustment'] as num?)?.toDouble(),
      signals:
          (json['signals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'adjustment': adjustment, 'signals': signals};
  }
}

class ModelResult {
  final String model;
  final String result;
  final double confidence;
  final String? reasoning;

  ModelResult({
    required this.model,
    required this.result,
    required this.confidence,
    this.reasoning,
  });

  factory ModelResult.fromJson(Map<String, dynamic> json) {
    return ModelResult(
      model:
          json['model'] as String? ?? json['model_name'] as String? ?? '',
      result: json['result'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] as String? ?? json['rationale'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'result': result,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }
}
