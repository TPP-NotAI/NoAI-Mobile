import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing ROOVERSE AI Detection API...');

  final uri = Uri.parse(
    'https://noai-lm-production.up.railway.app/api/v1/detect/text',
  );
  final request = http.MultipartRequest('POST', uri);
  request.fields['content'] =
      'This is a test sentence to check the API response format.';

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Status Code: ${response.statusCode}');
    print('Raw Body: ${response.body}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      print('Parsed Keys: ${json.keys.toList()}');
      if (json.containsKey('confidence')) {
        print(
          'Confidence: ${json['confidence']} (Type: ${json['confidence'].runtimeType})',
        );
      }
      if (json.containsKey('final_confidence')) {
        print('Final Confidence: ${json['final_confidence']}');
      }
      if (json.containsKey('result')) {
        print('Result: ${json['result']}');
      }
      if (json.containsKey('final_result')) {
        print('Final Result: ${json['final_result']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
