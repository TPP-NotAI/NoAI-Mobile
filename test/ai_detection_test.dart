import 'package:flutter_test/flutter_test.dart';
import 'package:rooverse/models/ai_detection_result.dart';

void main() {
  group('AiDetectionResult', () {
    test('fromJson parses correctly with documented field names', () {
      final json = {
        "analysis_id": "uuid-123",
        "result": "AI-GENERATED",
        "confidence": 98.5,
        "content_type": "text",
        "model_results": [
          {
            "model": "gpt-5.2",
            "result": "AI-GENERATED",
            "confidence": 99.0,
            "reasoning": "High perplexity",
          },
        ],
        "metadata_analysis": {
          "adjustment": -5.0,
          "signals": ["JPEG without EXIF data"],
        },
      };

      final result = AiDetectionResult.fromJson(json);

      expect(result.analysisId, 'uuid-123');
      expect(result.result, 'AI-GENERATED');
      expect(result.confidence, 98.5);
      expect(result.contentType, 'text');
      expect(result.modelResults, isNotNull);
      expect(result.modelResults!.length, 1);
      expect(result.modelResults![0].model, 'gpt-5.2');
      expect(result.metadataAnalysis, isNotNull);
      expect(
        result.metadataAnalysis!.signals,
        contains("JPEG without EXIF data"),
      );
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        "analysis_id": "uuid-456",
        "result": "HUMAN-GENERATED",
        "confidence": 10.0,
      };

      final result = AiDetectionResult.fromJson(json);

      expect(result.analysisId, 'uuid-456');
      expect(result.result, "HUMAN-GENERATED");
      expect(result.confidence, 10.0);
      expect(result.contentType, '');
      expect(result.modelResults, isNull);
    });

    test('toJson produces correct map', () {
      final json = {
        "analysis_id": "uuid-000",
        "result": "HUMAN-GENERATED",
        "confidence": 100.0,
        "content_type": "text",
        "model_results": [
          {
            "model": "model-1",
            "result": "HUMAN-GENERATED",
            "confidence": 100.0,
          },
        ],
      };

      final result = AiDetectionResult.fromJson(json);
      final encoded = result.toJson();

      expect(encoded['analysis_id'], "uuid-000");
      expect(encoded['result'], "HUMAN-GENERATED");
      expect(encoded['confidence'], 100.0);
      expect(encoded['model_results'], isA<List>());
      expect(encoded['model_results'][0]['model'], "model-1");
    });
  });
}
