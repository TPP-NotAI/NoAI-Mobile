import 'package:flutter_test/flutter_test.dart';
import 'package:noai/models/ai_detection_result.dart';

void main() {
  group('AiDetectionResult', () {
    test('fromJson parses correctly with fixed field names', () {
      final json = {
        "analysis_id": "uuid-123",
        "final_result": "AI-GENERATED",
        "final_confidence": 98.5,
        "content_type": "text",
        "model_analyses": [
          {"model": "gpt-5.2", "result": "AI-GENERATED", "confidence": 99.0},
        ],
        "metadata": {"timestamp": "2026-02-01T10:30:00Z"},
      };

      final result = AiDetectionResult.fromJson(json);

      expect(result.analysisId, 'uuid-123');
      expect(result.result, 'AI-GENERATED');
      expect(result.confidence, 98.5);
      expect(result.contentType, 'text');
      expect(result.modelAnalyses, isNotNull);
      expect(result.modelAnalyses!.length, 1);
      expect(result.modelAnalyses![0]['model'], 'gpt-5.2');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        "analysis_id": "uuid-456",
        "final_result": "HUMAN-GENERATED",
        "final_confidence": 10.0,
      };

      final result = AiDetectionResult.fromJson(json);

      expect(result.analysisId, 'uuid-456');
      expect(result.result, "HUMAN-GENERATED");
      expect(result.confidence, 10.0);
      expect(result.contentType, '');
      expect(result.modelAnalyses, isNull);
    });
  });
}
